defmodule ExBanking.User.SupervisorTest do

  use ExUnit.Case

  alias ExBanking.User.Supervisor, as: UserSupervisor

  test "create user" do
    assert {:ok, u} = UserSupervisor.start_user(username: "u")
    assert {:error, {:already_registered, ^u}} = UserSupervisor.start_user(username: "u")
  end

end
