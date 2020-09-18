defmodule ExBanking.User.PendingLimit do

  def new() do
    :ets.new(__MODULE__, [
      :named_table, :public,
      write_concurrency: true,
      read_concurrency:  true
    ])
  end

  def increase(username, limit \\ 10) do
    limit = limit + 1
    counter = :ets.update_counter(__MODULE__, username, {2, 1, limit, limit}, {username, 0})
    if counter >= limit do
      {:error, :too_many_requests_to_user}
    else
      {:ok, counter}
    end
  end

  def decrease(username) do
    :ets.update_counter(__MODULE__, username, {2, -1})
    :ok
  end

end
