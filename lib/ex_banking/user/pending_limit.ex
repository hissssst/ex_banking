defmodule ExBanking.User.PendingLimit do

  def increase(username, limit) do
    [{pending, _}] = Registry.lookup(UsersRegistry, username)
    if pending > limit do
      {:error, :too_many_requests}
    else
      {new, _} = Registry.update_value(UsersRegistry, username, & &1 + 1)
      {:ok, new}
    end
  end

  def decrease(username) do
    {new, _} = Registry.update_value(UsersRegistry, username, & &1 - 1)
    {:ok, new}
  end

end
