defmodule ExBankingTest do

  use ExUnit.Case

  test "create user" do
    name = "user creation test"
    assert :ok = ExBanking.create_user(name)
    assert {:error, :user_already_exists} = ExBanking.create_user(name)
    assert {:error, :wrong_arguments} = ExBanking.create_user(1)
  end

  test "deposit" do
    name = "deposit test"
    assert :ok = ExBanking.create_user(name)
    assert {:ok, 10.0} = ExBanking.deposit(name, 10, "USD")
    assert {:ok, 1010.0} = ExBanking.deposit(name, 1000, "USD")
    assert {:error, :wrong_arguments} = ExBanking.deposit(name, 1, 1)
    assert {:error, :wrong_arguments} = ExBanking.deposit(name, "1", "USD")

    assert {:error, :user_does_not_exist} = ExBanking.deposit("", 1, "USD")
  end

  test "withdraw" do
    name = "withdraw test"
    assert :ok = ExBanking.create_user(name)
    assert {:ok, 10.0} = ExBanking.deposit(name, 10, "USD")
    assert {:ok, 5.0} = ExBanking.withdraw(name, 5, "USD")
    assert {:ok, 0.0} = ExBanking.withdraw(name, 5, "USD")
    assert {:error, :not_enough_money} = ExBanking.withdraw(name, 5, "USD")
    assert {:error, :wrong_arguments} = ExBanking.withdraw(name, 1, 1)
    assert {:error, :wrong_arguments} = ExBanking.withdraw(name, "1", "USD")

    assert {:error, :user_does_not_exist} = ExBanking.withdraw("", 1, "USD")
  end

  test "get_balance" do
    name = "get_balance test"
    assert :ok = ExBanking.create_user(name)
    assert {:ok, 10.0} = ExBanking.deposit(name, 10, "USD")
    assert {:ok, 10.0} = ExBanking.get_balance(name, "USD")
    assert {:error, :wrong_arguments} = ExBanking.get_balance(name, 1)
    assert {:error, :wrong_arguments} = ExBanking.get_balance(name, USD)

    assert {:error, :user_does_not_exist} = ExBanking.get_balance("", "USD")
  end

  test "send" do
    name1 = "send test1"
    name2 = "send test2"
    assert :ok = ExBanking.create_user(name1)
    assert :ok = ExBanking.create_user(name2)
    assert {:ok, 10.0} = ExBanking.deposit(name1, 10, "USD")
    assert {:ok, 10.0} = ExBanking.deposit(name2, 10, "USD")
    assert {:ok, 5.0, 15.0} = ExBanking.send(name1, name2, 5, "USD")
    assert {:ok, 0.0, 20.0} = ExBanking.send(name1, name2, 5, "USD")
    assert {:error, :not_enough_money} = ExBanking.send(name1, name2, 5, "USD")

    assert {:error, :sender_does_not_exist} = ExBanking.send("", name2, 5, "USD")
    assert {:error, :receiver_does_not_exist} = ExBanking.send(name1, "", 5, "USD")
  end

end
