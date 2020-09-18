defmodule ExBanking do

  @moduledoc """
  Documentation for `ExBanking`.
  """

  alias ExBanking.User

  @type banking_error :: {:error,
    :wrong_arguments                |
    :user_already_exists            |
    :user_does_not_exist            |
    :not_enough_money               |
    :sender_does_not_exist          |
    :receiver_does_not_exist        |
    :too_many_requests_to_user      |
    :too_many_requests_to_sender    |
    :too_many_requests_to_receiver
  }

  @type user :: String.t()
  @type currency :: String.t()

  defguard is_user(u) when is_binary(u)
  defguard is_amount(a) when (is_integer(a) or is_float(a)) and a >= 0
  defguard is_currency(c) when is_binary(c)

  defmacrop with_exsisting_user(user, do: code) do
    quote do
      case User.exsists?(unquote(user)) do
        true ->
          unquote(code)

        false ->
          {:error, :user_does_not_exist}
      end
    end
  end

  @spec create_user(user) :: :ok | banking_error
  def create_user(user) when is_user(user) do
    case User.create(user) do
      {:ok, _} -> :ok
      {:error, {:already_registered, _}} -> {:error, :user_already_exists}
    end
  end
  def create_user(_), do: {:error, :wrong_arguments}

  @spec deposit(user, number, currency) :: {:ok, number} | banking_error
  def deposit(user, amount, currency) when is_user(user) and is_amount(amount) and is_currency(currency) do
    with_exsisting_user(user) do
      User.call_action(user, :add, [amount, currency])
    end
  end
  def deposit(_, _, _), do: {:error, :wrong_arguments}

  @spec withdraw(user, number, currency) :: {:ok, number} | banking_error
  def withdraw(user, amount, currency) when is_user(user) and is_amount(amount) and is_currency(currency) do
    with_exsisting_user(user) do
      User.call_action(user, :sub, [amount, currency])
    end
  end
  def withdraw(_, _, _), do: {:error, :wrong_arguments}

  @spec get_balance(user, currency) :: {:ok, number} | banking_error
  def get_balance(user, currency) when is_user(user) and is_currency(currency) do
    with_exsisting_user(user) do
      User.call_action(user, :get, [currency])
    end
  end
  def get_balance(_, _), do: {:error, :wrong_arguments}

  @spec send(user, user, number, currency) :: {:ok, number, number} | banking_error
  def send(from, to, amount, currency
  ) when is_user(from) and is_user(to) and is_amount(amount) and is_currency(currency) do
    with(
      {:from, true}     <- {:from, User.exsists?(from)},
      {:to,   true}     <- {:to,   User.exsists?(to)},
      id                <- make_ref(),
      {:from, {:ok, _}} <- {:from, User.enter_transaction(from, transaction_id: id)},
      {:to,   {:ok, _}} <- {:to, User.enter_transaction(to,   transaction_id: id)}
    ) do
      with(
        {:ok, new_from} <- User.call_in_transaction(from, id, :sub, [amount, currency]),
        {:ok, new_to}   <- User.call_in_transaction(to, id, :add, [amount, currency])
      ) do
        User.commit(from, id)
        User.commit(to, id)
        {:ok, new_from, new_to}
      else
        {:error, :not_enough_money} ->
          User.rollback(from, id)
          User.rollback(to, id)
          {:error, :not_enough_money}
      end
    else
      {:from, false} ->
        {:error, :sender_does_not_exist}

      {:to, false} ->
        {:error, :receiver_does_not_exist}

      {:from, {:error, :too_many_requests_to_user}} ->
        {:error, :too_many_requests_to_sender}

      {:to, {:error, :too_many_requests_to_user}} ->
        {:error, :too_many_requests_to_receiver}
    end
  end
  def send(_, _, _, _), do: {:error, :wrong_arguments}

end
