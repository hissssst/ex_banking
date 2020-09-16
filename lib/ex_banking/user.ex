defmodule ExBanking.User do

  use Core.Sys

  require Pathex
  alias ExBanking.Wallet
  alias ExBanking.User.PendingLimit

  # Dialyzer works really bad with Core
  @dialyzer {:nowarn_function, [
    loop_transaction: 4,
    loop_normal: 3,
    start_link: 1
  ]}

  @transaction_timeout if Mix.env() == :dev, do: 100_000, else: 5_000

  @type option :: {:username, String.t()}
    | {:transaction_timeout, timeout()}

  @type state :: %{
    user_data: %{
      username: ExBanking.user(),
      wallet:   Wallet.t()
    },
    transaction_id: nil | reference(),
    settings: %{
      transaction_timeout: timeout()
    }
  }

  @typep transaction_return() :: {:ok, {:commit, state()}}
    | {:ok, :rollback}
    | {:error, :timeout, state()}

  # Public API

  def call_action(username, action, arguments, opts \\ []
  ) when is_list(opts) and is_binary(username) and is_list(arguments) and is_atom(action) do
    do_call_with_limit(username, {:wallet_action, action, arguments}, opts)
  end

  def enter_transaction(username, opts) when is_binary(username) and is_list(opts) do
    id = make_ref()
    case do_call_with_limit(username, {:enter_transaction, id}, opts) do
      :ok ->
        {:ok, id}

      other ->
        {:error, other}
    end
  end

  def in_transaction(username, transaction_id, action, arguments, opts
  ) when is_list(opts) and is_binary(username) and is_list(arguments) and is_atom(action) do
    timeout = opts[:timeout] || 5_000
    do_call(username, {:in_transaction, transaction_id, {:wallet_action, action, arguments}}, timeout)
  end

  def rollback(username, transaction_id, opts) when is_binary(username) do
    timeout = opts[:timeout] || 5_000
    do_call(username, {:transaction_ctl, transaction_id, :rollback}, timeout)
  end

  def commit(username, transaction_id, opts) when is_binary(username) do
    timeout = opts[:timeout] || 5_000
    do_call(username, {:transaction_ctl, transaction_id, :commit}, timeout)
  end

  # Naming and start_link

  @spec server_name(ExBanking.user(), boolean()) :: Tuple.t()
  def server_name(username, for_start_link \\ false)
  def server_name(username, false) do
    {:via, Registry, {UsersRegistry, username}}
  end
  def server_name(username, true) do
    {:via, {Registry, {UsersRegistry, username, 0}}}
  end

  @spec start_link([option()]) :: Core.start_return()
  def start_link(opts) do
    username = Keyword.fetch!(opts, :username)
    Core.start_link(__MODULE__, opts, name: server_name(username, true))
  end

  # Handlers

  @spec handle_call(any(), Core.from(), state()) :: {:ok, state()} | {:stop, any(), state()}
  defp handle_call({:wallet_action, action, args}, from, state) do
    IO.inspect state, label: :here
    {:ok, wallet_action(state, from, action, args)}
  end
  defp handle_call(other, _, state) do
    IO.inspect other, lanel: :bad_call
    {:ok, state}
  end

  @spec terminate(state(), Core.parent(), Core.Debug.t(), any()) :: no_return()
  defp terminate(state, parent, debug, reason) do
    event = { :EXIT, reason }
    Core.stop(__MODULE__, state, parent, debug, reason, event)
  end

  # Core Sys API

  @spec system_continue(state(), Core.parent(), Core.Debug.t()) :: no_return()
  def system_continue(state, parent, debug), do: loop_normal(state, parent, debug)

  @spec system_terminate(state(), Core.parent(), Core.Debug.t(), any()) :: no_return()
  def system_terminate(state, parent, debug, reason) do
    terminate(state, parent, debug, reason)
  end

  def init(parent, debug, opts) do
    {:ok, wallet} = Wallet.new()
    state = %{
      user_data: %{
        wallet: wallet,
        username: Keyword.fetch!(opts, :username)
      },
      transaction_id: nil,
      settings: %{
        transaction_timeout: opts[:transaction_timeout] || @transaction_timeout
      }
    }

    Core.init_ack()
    loop_normal(state, parent, debug)
  end

  # Core Sys logic

  @spec loop_normal(state(), Core.parent(), Core.Debug.t()) :: no_return()
  defp loop_normal(state, parent, debug) do
    Core.Sys.receive(__MODULE__, state, parent, debug) do
      {__MODULE__, from, {:enter_transaction, transaction_id}} ->
        state = set_transaction_id(state, transaction_id)
        Core.reply(from, :ok)
        case loop_transaction(state, parent, debug, state.settings.transaction_timeout) do
          {:ok, {:commit, new_state}} ->
            new_state
            |> set_transaction_id(nil)
            |> loop_normal(parent, debug)

          {:ok, :rollback} ->
            loop_normal(state, parent, debug)

          {:error, :timeout, _new_state} ->
            # 2PC local decidion is rollback
            loop_normal(state, parent, debug)

          other ->
            terminate(state, parent, debug, {:unexpected_transaction_exit, other})
        end

      {__MODULE__, from, msg} ->
        case handle_call(msg, from, state) do
          {:ok, new_state} ->
            loop_normal(new_state, parent, debug)

          {:stop, reason, new_state} ->
            terminate(new_state, parent, debug, reason)
        end
    end
  end

  @spec loop_transaction(state(), Core.parent(), Core.Debug.t(), timeout()) :: transaction_return()
  defp loop_transaction(state, parent, debug, timeout) do
    transaction_id = get_transaction_id(state)
    Core.Sys.receive(__MODULE__, state, parent, debug) do
      {__MODULE__, from, {:in_transaction, ^transaction_id, msg}} ->
        case handle_call(msg, from, state) do
          {:ok, new_state} ->
            loop_transaction(new_state, parent, debug, timeout)

          {:stop, reason, new_state} ->
            terminate(new_state, parent, debug, reason)
        end

      {__MODULE__, from, {:transaction_ctl, ^transaction_id, :rollback}} ->
        Core.reply(from, :ok)
        {:ok, :rollback}

      {__MODULE__, from, {:transaction_ctl, ^transaction_id, :commit}} ->
        Core.reply(from, :ok)
        {:ok, {:commit, state}}

      after timeout ->
        {:error, :timeout, state}
    end
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

  # Helpers

  defp get_transaction_id(%{transaction_id: id}), do: id

  defp set_transaction_id(state, id), do: %{state | transaction_id: id}

  defp wallet_lense() do
    Pathex.path :user_data / :wallet, :map
  end

  defp do_call(username, message, timeout) do
    username
    |> server_name()
    |> Core.call(__MODULE__, message, timeout)
  end

  defp do_call_with_limit(username, message, opts) do
    limit   = opts[:limit]   || 10
    timeout = opts[:timeout] || 5000
    case PendingLimit.increase(username, limit) do
      {:ok, _} ->
        do_call(username, message, timeout)

      {:error, _} ->
        {:error, :too_many_requests}
    end
  after
    PendingLimit.decrease(username)
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
