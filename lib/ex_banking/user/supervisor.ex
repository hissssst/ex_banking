defmodule ExBanking.User.Supervisor do

  @moduledoc """
  This supervisor starts Registry and DynamicSupervisor for
  supervising user's processes
  """

  use Supervisor

  alias ExBanking.User
  alias ExBanking.User.PendingLimit

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    PendingLimit.new()
    [
      users_supervisor_spec(opts),
      registry_spec(opts)
    ]
    |> Supervisor.init(strategy: :rest_for_one)
  end

  defp registry_spec(_opts) do
    opts = [name: UsersRegistry, keys: :unique]
    %{
      id: :users_registry,
      type: :worker,
      start: {Registry, :start_link, [opts]}
    }
  end

  defp users_supervisor_spec(_opts) do
    opts = [strategy: :one_for_one, name: UserSupervisor]
    %{
      id: :users_supervisor,
      type: :supervisor,
      start: {DynamicSupervisor, :start_link, [opts]}
    }
  end

  def start_user(opts) do
    spec = User.child_spec(opts)
    DynamicSupervisor.start_child(UserSupervisor, spec)
  end

end
