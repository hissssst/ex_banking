defmodule ExBanking.WalletTest do

  use ExUnit.Case, async: true
  alias ExBanking.Wallet

  test "add and get test" do
    assert {:ok, wallet} = Wallet.new()
    assert {wallet, _} = Wallet.add(wallet, 10, "USD")

    assert {^wallet, {:ok, 10.0}} = Wallet.get(wallet, "USD")
  end

  test "add, sub and get test" do
    assert {:ok, wallet} = Wallet.new()
    assert {wallet, _} = Wallet.add(wallet, 10, "USD")
    assert {wallet, _} = Wallet.sub(wallet, 6, "USD")
    assert {wallet, _} = Wallet.sub(wallet, 4, "USD")

    assert {^wallet, {:ok, 0.0}} = Wallet.get(wallet, "USD")
    assert {^wallet, {:error, :not_enough_money}} = Wallet.sub(wallet, 6, "USD")
  end

  test "multiple add test" do
    assert {:ok, wallet} = Wallet.new()
    assert {wallet, _} = Wallet.add(wallet,     10   , "USD")
    assert {wallet, _} = Wallet.add(wallet, 100_000   , "USD")
    assert {wallet, _} = Wallet.add(wallet, 100_000   , "USD")
    assert {wallet, _} = Wallet.add(wallet,      0.01, "USD")
    assert {^wallet, {:ok, 200_010.01}} = Wallet.get(wallet, "USD")
  end

  test "Different currencies test" do
    assert {:ok, wallet} = Wallet.new()
    assert {wallet, _} = Wallet.add(wallet, 10 , "USD")
    assert {wallet, _} = Wallet.add(wallet, 10 , "RUB")
    assert {wallet, _} = Wallet.add(wallet, 10 , "XTB")
    assert {wallet, _} = Wallet.add(wallet, 10 , "...")
    assert {^wallet, {:ok, 10.0}} = Wallet.get(wallet, "USD")
    assert {^wallet, {:ok, 10.0}} = Wallet.get(wallet, "RUB")
    assert {^wallet, {:ok, 10.0}} = Wallet.get(wallet, "XTB")
    assert {^wallet, {:ok, 10.0}} = Wallet.get(wallet, "...")
  end

  test "Random test" do
    assert {:ok, wallet} = Wallet.new()
    Enum.reduce(1..10_000, wallet, fn _, wallet ->
      x = :rand.uniform(10_000) / 100
      assert {wallet, {:ok, _}} = Wallet.add(wallet, x, "USD")

      assert {wallet, {:ok, v}} = Wallet.get(wallet, "USD")

      x = :rand.uniform(10_000) / 100
      if x > v do
        assert {wallet, {:error, :not_enough_money}} = Wallet.sub(wallet, x, "USD")
        wallet
      else
        assert {wallet, {:ok, _}} = Wallet.sub(wallet, x, "USD")
        wallet
      end
    end)
  end

  test "Decimal precision" do
    assert {:ok, wallet} = Wallet.new()
    assert {wallet, {:ok, _}} = Wallet.add(wallet, 10, "USD")
    assert {wallet, {:ok, 1_000}} = Wallet.get(wallet, "USD", decimal: true)
    assert {wallet, {:ok, _}} = Wallet.add(wallet, 10, "USD")
    assert {wallet, {:ok, 2_000}} = Wallet.get(wallet, "USD", decimal: true)
  end

end
