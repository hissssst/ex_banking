defmodule ExBanking.User.Supervisor do

  use Supervisor

  alias ExBanking.User

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    [
      users_supervisor_spec(opts),
      registry_spec(opts)
    ]
    |> Supervisor.init(strategy: :rest_for_one)
  end

  defp registry_spec(opts) do
    partitions = opts[:registry_partitions] || System.schedulers_online()
    opts = [name: UsersRegistry, keys: :unique, partitions: partitions]
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
