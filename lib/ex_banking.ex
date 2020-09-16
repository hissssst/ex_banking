defmodule ExBanking do

  @moduledoc """
  Documentation for `ExBanking`.
  """

  @type banking_error :: {:error,
    :wrong_arguments                |
    :user_already_exists            |
    :user_does_not_exist            |
    :not_enough_money               |
    :sender_does_not_exist          |
    :receiver_does_not_exist        |
    :too_many_requests_to_user      |
    :too_many_requests_to_sender    |
    :too_many_requests_to_receiver
  }

  @type user :: String.t()
  @type currency :: String.t()

  @spec create_user(user) :: :ok | banking_error
  def create_user(user) do

  end

  @spec deposit(user, number, currency) :: {:ok, number} | banking_error
  def deposit(user, amount, currency) do

  end

  @spec withdraw(user, number, currency) :: {:ok, number} | banking_error
  def withdraw(user, amount, currency) do

  end

  @spec get_balance(user, currency) :: {:ok, number} | banking_error
  def get_balance(user, currency) do

  end

  @spec send(user, user, number, currency) :: {:ok, number, number} | banking_error
  def send(from, to, amount, currency) do

  end

end
