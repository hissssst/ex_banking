defmodule ExBanking.User do

  @moduledoc """
  This module represents user process which stores user's state
  and performs actions and transactions with user

  This module is implemented with `Core` library which is library
  for building opt-compliant selective receive processes.

  It operates in two modes:
  * When not in transaction
  * When in transaction

  ### Transactions

  When in transaction, process answers to all non-transactional calls
  When not in transaction, process answers only to transactional calls with appropriate id

  When this process enters transaction, it saves it's current state and enters transaction
  with copy of currend state.
  When process leaves the transaction with rollback (or timeout) it swaps it's current state
  with the state it saved when entered transaction.
  When process leaves the transaction with commit it continues with state after transaction

  ### Pending requests limit

  It is done via external `:ets` with counters. Every process has {username, pending_requests_count}
  entry in this `:ets`. Every non-transactional call is counted as one request. Entering transaction call
  is also counter as one request
  """

  use Core.Sys

  require Pathex
  alias ExBanking.Wallet
  alias ExBanking.User.PendingLimit
  alias ExBanking.User.Supervisor, as: UserSupervisor

  import ExBanking, only: [is_user: 1]

  # Dialyzer works really bad with Core
  @dialyzer {:nowarn_function, [
    loop_transaction: 4,
    loop_normal: 3,
    start_link: 1,
    init: 3 # Some dialyzer bug here
  ]}

  @transaction_timeout if Mix.env() == :dev, do: 100_000, else: 5_000

  @type transaction_id :: reference()

  @typedoc """
  Set of options for calling start_link.
  You can specify transaction timeout and username here
  """
  @type start_option :: {:username, String.t()} | {:transaction_timeout, timeout()}

  @typedoc """
  Limit: pending processes limit
  Timeout: call timeout (like in `GenServer`)
  """
  @type call_option :: {:limit, pos_integer()} | {:timeout, timeout()}

  @typedoc """
  Timeout: call timeout (like in `GenServer`)
  """
  @type transaction_call_option :: {:timeout, timeout()}

  @typedoc """
  user_data: map of user fields
  transaction_id: id of current transaction or nil if user is not in transaction now
  settings: private info for transaction control
  """
  @type state :: %{
    user_data: %{
      username: ExBanking.user(),
      wallet:   Wallet.t()
    },
    transaction_id: nil | transaction_id(),
    settings: %{
      transaction_timeout: timeout()
    }
  }

  @typep transaction_return() :: {:ok, {:commit, state()}}
    | {:ok, :rollback}
    | {:error, :timeout, state()}

  # Public API

  @spec create(ExBanking.user()) :: Core.start_return()
  def create(username) when is_user(username) do
    UserSupervisor.start_user(username: username)
  end

  @spec exsists?(ExBanking.user()) :: boolean()
  def exsists?(username) when is_user(username) do
    match? [_], Registry.lookup(UsersRegistry, username)
  end

  # Operations API

  @doc """
  Calls wallet function with specified arguments
  """
  @spec call_action(ExBanking.user(), atom(), list(), [call_option()]) :: any()
  def call_action(username, action, arguments, opts \\ []
  ) when is_list(opts) and is_user(username) and is_list(arguments) and is_atom(action) do
    do_call_with_limit(username, {:wallet_action, action, arguments}, opts)
  end

  @doc """
  Starts transaction on given user with given (or automatically generated) transaction id
  """
  @spec enter_transaction(ExBanking.user(), [call_option() | {:transaction_id, transaction_id()}]
  ) :: {:ok, transaction_id()} | {:error, any()}
  def enter_transaction(username, opts \\ []) when is_user(username) and is_list(opts) do
    id = opts[:transaction_id] || make_ref()
    case do_call_with_limit(username, {:enter_transaction, id}, opts) do
      :ok ->
        {:ok, id}

      other ->
        {:error, other}
    end
  end

  @spec call_in_transaction(ExBanking.user(), transaction_id(), atom(), list(), [transaction_call_option()]) :: any()
  def call_in_transaction(username, transaction_id, action, arguments, opts \\ []
  ) when is_list(opts) and is_user(username) and is_list(arguments) and is_atom(action) do
    timeout = opts[:timeout] || 5_000
    do_call(username, {:in_transaction, transaction_id, {:wallet_action, action, arguments}}, timeout)
  end

  @spec rollback(ExBanking.user(), transaction_id(), [transaction_call_option()]) :: :ok
  def rollback(username, transaction_id, opts \\ []) when is_user(username) do
    timeout = opts[:timeout] || 5_000
    do_call(username, {:transaction_ctl, transaction_id, :rollback}, timeout)
  end

  @spec commit(ExBanking.user(), transaction_id(), [transaction_call_option()]) :: :ok
  def commit(username, transaction_id, opts \\ []) when is_user(username) do
    timeout = opts[:timeout] || 5_000
    do_call(username, {:transaction_ctl, transaction_id, :commit}, timeout)
  end

  # Naming and start_link

  @spec server_name(ExBanking.user()) :: {:via, Registry, {UsersRegistry, ExBanking.user()}}
  def server_name(username) do
    {:via, Registry, {UsersRegistry, username}}
  end

  @spec start_link([start_option()]) :: Core.start_return()
  def start_link(opts \\ []) do
    Core.start_link(__MODULE__, opts)
  end

  # Handlers

  @spec handle_call(any(), Core.from(), state()) :: {:ok, state()} | {:stop, any(), state()}
  defp handle_call({:wallet_action, action, args}, from, state) do
    {:ok, wallet_action(state, from, action, args)}
  end
  defp handle_call(_other, _, state) do
    {:ok, state}
  end

  @spec terminate(state(), Core.parent(), Core.Debug.t(), any()) :: no_return()
  defp terminate(state, parent, debug, reason) do
    event = {:EXIT, reason}
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
    with(
      {:ok, wallet}   <- Wallet.new(),
      {:ok, username} <- Keyword.fetch(opts, :username),
      {:ok, _}        <- Registry.register(UsersRegistry, username, 0)
    ) do
      state = %{
        user_data: %{
          wallet: wallet,
          username: username
        },
        transaction_id: nil,
        settings: %{
          transaction_timeout: opts[:transaction_timeout] || @transaction_timeout
        }
      }

      Core.init_ack()
      loop_normal(state, parent, debug)
    else
      {:error, other} ->
        Core.init_stop(__MODULE__, parent, debug, opts, other)
      :error ->
        Core.init_stop(__MODULE__, parent, debug, opts, {:error, :no_username})
      #other  -> Core.init_stop(__MODULE__, parent, debug, opts, other)
    end
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
        {:error, :too_many_requests_to_user}
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
