defmodule ExBanking.User do

  require Pathex
  alias ExBanking.Wallet
  alias __MODULE__.State

  #TODO
  @type state :: any()

  # Naming and start_link

  def server_name(username, with_value \\ false)
  def server_name(username, false) do
    {:via, Registry, {UsersRegistry, username}}
  end
  def server_name(username, true) do
    {:via, Registry, {UsersRegistry, username, 0}}
  end

  def start_link(opts) do
    username = Keyword.fetch!(opts, :username)
    Core.start_link(__MODULE__, opts, name: server_name(username, true))
  end

  def init(parent, debug, opts) do
    {:ok, wallet} = Wallet.new()
    state = %{
      user_data: %{
        wallet:   wallet,
        username: Keyword.fetch!(opts, :username)
      }
    }
    loop_normal(state, parent, debug)
  end

  # Selective receive part

  def loop_normal()

  defp handle_call({:wallet_action, action, args}, from, state) do
    wallet_action(state, from, action, args)
  end

  # Helpers

  # This one looks nasty, but I've tried my best in Wallet's interface isolation
  @spec wallet_action(state(), Core.from(), atom(), list()) :: state()
  defp wallet_action(state, reply_to, action, args) do
    {:ok, state} =
      Pathex.over(wallet_lense(), state, fn wallet ->
        {wallet, reply} = apply(Wallet, action, [wallet | args])
        Core.reply(reply_to, reply)
        wallet
      end)
    state
  rescue
    _ in UndefinedFunctionError ->
      Core.reply(reply_to, :unknown_action)
      state
  end

  defp username_lense() do
    Pathex.path :user_data / :username, :map
  end

  defp wallet_lense() do
    Pathex.path :user_data / :wallet, :map
  end

  # Child spec for supervisor

  def child_spec(opts) do
    %{
      id: Keyword.fetch!(opts, :username),
      type: :worker,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

end
