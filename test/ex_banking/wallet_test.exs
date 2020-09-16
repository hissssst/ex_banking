defmodule ExBanking.WalletTest do

  use ExUnit.Case, async: true
  alias ExBanking.Wallet

  test "add and get test" do
    assert {:ok, wallet} = Wallet.new()
    assert {wallet, _} = Wallet.add(wallet, 10, "USD")

    assert {^wallet, 10.0} = Wallet.get(wallet, "USD")
  end

  test "add, sub and get test" do
    assert {:ok, wallet} = Wallet.new()
    assert {wallet, _} = Wallet.add(wallet, 10, "USD")
    assert {wallet, _} = Wallet.sub(wallet, 6, "USD")
    assert {wallet, _} = Wallet.sub(wallet, 4, "USD")

    assert {^wallet, 0.0} = Wallet.get(wallet, "USD")
    assert {^wallet, :not_enough_money} = Wallet.sub(wallet, 6, "USD")
  end

  test "multiple add test" do
    assert {:ok, wallet} = Wallet.new()
    assert {wallet, _} = Wallet.add(wallet,     10   , "USD")
    assert {wallet, _} = Wallet.add(wallet, 100000   , "USD")
    assert {wallet, _} = Wallet.add(wallet, 100000   , "USD")
    assert {wallet, _} = Wallet.add(wallet,      0.01, "USD")
    assert {^wallet, 200010.01} = Wallet.get(wallet, "USD")
  end

  test "Different currencies test" do
    assert {:ok, wallet} = Wallet.new()
    assert {wallet, _} = Wallet.add(wallet, 10 , "USD")
    assert {wallet, _} = Wallet.add(wallet, 10 , "RUB")
    assert {wallet, _} = Wallet.add(wallet, 10 , "XTB")
    assert {wallet, _} = Wallet.add(wallet, 10 , "...")
    assert {^wallet, 10.0} = Wallet.get(wallet, "USD")
    assert {^wallet, 10.0} = Wallet.get(wallet, "RUB")
    assert {^wallet, 10.0} = Wallet.get(wallet, "XTB")
    assert {^wallet, 10.0} = Wallet.get(wallet, "...")
  end

end
