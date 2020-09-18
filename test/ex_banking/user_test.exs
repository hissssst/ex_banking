defmodule ExBanking.UserTest do

  use ExUnit.Case
  alias ExBanking.User

  test "create user" do
    assert {:ok, u} = User.create("user")
    assert {:error, {:already_registered, ^u}} = User.create("user")
  end

  test "user exsists check" do
    name = "this user doesn't exsist"
    assert {:ok, _} = User.create(name)
    assert true == User.exsists?(name)
    assert false == User.exsists?(name <> "well not")
  end

  test "action call with limit and stuff" do
    name = "actually a user"
    assert {:ok, _} = User.create(name)
    assert {:ok, 10.0} = User.call_action(name, :add, [10, "USD"])
    assert {:error, :too_many_requests_to_user} = User.call_action(name, :add, [10, "USD"], limit: 0)
    assert {:ok, 0.0} = User.call_action(name, :sub, [10, "USD"])
    assert {:error, :not_enough_money} = User.call_action(name, :sub, [10, "USD"])
  end

  test "transaction rollback" do
    name = "transaction rollback user"
    assert {:ok, _} = User.create(name)
    assert {:ok, 10.0} = User.call_action(name, :add, [10, "USD"])

    assert {:ok, id} = User.enter_transaction(name)
    assert {:ok, 20.0} = User.call_in_transaction(name, id, :add, [10, "USD"])
    assert :ok = User.rollback(name, id)

    assert {:ok, 10.0} = User.call_action(name, :get, ["USD"])
  end

  test "transaction commit" do
    name = "transaction commit user"
    assert {:ok, _} = User.create(name)
    assert {:ok, 10.0} = User.call_action(name, :add, [10, "USD"])

    assert {:ok, id} = User.enter_transaction(name)
    assert {:ok, 20.0} = User.call_in_transaction(name, id, :add, [10, "USD"])
    assert :ok = User.commit(name, id)

    assert {:ok, 20.0} = User.call_action(name, :get, ["USD"])
  end

  test "server name test" do
    name = "xxadsfwefq34g2br"
    assert {:via, Registry, {UsersRegistry, ^name}} = User.server_name(name)
  end

end
