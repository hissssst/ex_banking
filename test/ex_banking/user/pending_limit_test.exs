defmodule ExBanking.User.PendingLimitTest do

  use ExUnit.Case
  alias ExBanking.User.PendingLimit

  test "default value" do
    name = "default value test key"
    assert {:ok, 1} = PendingLimit.increase(name)
  end

  test "increase to limit" do
    name = "increase to limit test key"
    assert {:ok, 1} = PendingLimit.increase(name, 2)
    assert {:ok, 2} = PendingLimit.increase(name, 2)
    assert {:error, :too_many_requests_to_user} = PendingLimit.increase(name, 2)
  end

  test "decrease" do
    name = "decrease test key"
    assert {:ok, 1} = PendingLimit.increase(name, 2)
    assert :ok = PendingLimit.decrease(name)

    assert {:ok, 1} = PendingLimit.increase(name, 2)
    assert {:ok, 2} = PendingLimit.increase(name, 2)
    assert :ok = PendingLimit.decrease(name)
    assert :ok = PendingLimit.decrease(name)
  end

end
