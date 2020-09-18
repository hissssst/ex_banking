defmodule ExBanking.Wallet do

  @moduledoc """
  Wallet is a state of users currencies
  Almost every wallet-manipulation function
  returns {wallet, result}
  """

  @compile {:inline, currency_lense: 1}

  require Pathex
  import Pathex, only: [path: 2]

  @enforce_keys ~w[precision pow]a
  defstruct [state: %{}] ++ @enforce_keys

  @typedoc "Values if this type are stored in wallet values"
  @opaque decimal :: pos_integer()
  @typep currency :: ExBanking.currency()
  @type t :: %__MODULE__{
    state: %{ExBanking.currency() => pos_integer()},
    precision: pos_integer(),
    pow:       pos_integer()
  }
  @type new_option :: {:precision, pos_integer()}
  @type get_option :: {:decimal, boolean()}

  # Public

  @spec new([new_option()]) :: {:ok, t()}
  def new(opts \\ []) do
    precision = opts[:precision] ||  2
    {:ok, %__MODULE__{precision: precision, pow: power(10, precision)}}
  end

  @spec add(t(), number(), currency()) :: {t(), {:ok, number()}}
  def add(%__MODULE__{} = wallet, amount, currency) do
    amount = to_decimal(amount, wallet)
    lense = currency_lense(currency)
    wallet = force_update(lense, wallet, amount, & &1 + amount)
    {:ok, newvalue} = Pathex.view(lense, wallet)
    {wallet, {:ok, to_float(newvalue, wallet)}}
  end

  @spec sub(t(), number(), currency()) :: {t(), {:ok, number()} | {:error, :not_enough_money}}
  def sub(%__MODULE__{} = wallet, amount, currency) do
    amount = to_decimal(amount, wallet)
    lense = currency_lense(currency)
    with(
      {:ok, value} <- Pathex.view(lense, wallet),
      true <- value >= amount
    ) do
      new_value = value - amount
      {:ok, wallet} = Pathex.set(lense, wallet, new_value)
      {wallet, {:ok, to_float(new_value, wallet)}}
    else
      _ -> {wallet, {:error, :not_enough_money}}
    end
  end

  @spec get(t(), currency(), [get_option()]) :: {t(), {:ok, float() | decimal()}}
  def get(wallet, currency, opts \\ [])
  def get(%__MODULE__{} = wallet, currency, decimal: true) do
    case Pathex.view(currency_lense(currency), wallet) do
      {:ok, value} -> {wallet, {:ok, value}}
      :error       -> {wallet, {:ok, 0}}
    end
  end
  def get(%__MODULE__{} = wallet, currency, _) do
    case Pathex.view(currency_lense(currency), wallet) do
      {:ok, value} -> {wallet, {:ok, to_float(value, wallet)}}
      :error       -> {wallet, {:ok, 0.00}}
    end
  end

  # Privates

  @spec to_decimal(number(), t()) :: decimal()
  defp to_decimal(value, %{pow: pow}), do: round(value * pow)

  @spec to_float(decimal(), t()) :: float()
  defp to_float(value, %{pow: pow}), do: value / pow

  @spec currency_lense(ExBanking.currency()) :: Pathex.t()
  defp currency_lense(currency) do
    path :state / currency, :map
  end

  @spec force_update(Pathex.t(), any(), any(), (any() -> any())) :: any()
  defp force_update(path, structure, default, func) do
    case Pathex.over(path, structure, func) do
      {:ok, new_structure} ->
        new_structure

      _ ->
        Pathex.force_set(path, structure, default)
        |> elem(1)
    end
  end

  @spec power(pos_integer(), non_neg_integer(), pos_integer()) :: pos_integer()
  defp power(int, power, acc \\ 1)
  defp power(_, 0, acc), do: acc
  defp power(int, power, acc) do
    power(int, power - 1, acc * int)
  end

end
