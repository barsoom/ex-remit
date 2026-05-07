defmodule RemitWeb.OAuth.UsedCodes do
  @moduledoc """
  Remembers redeemed authorization codes until they expire, so each one is
  exchanged at most once. In memory, like `Remit.GithubAuth` state tokens.
  """
  use Agent

  def start_link(_), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  def consume(jti, exp) do
    Agent.get_and_update(__MODULE__, fn used ->
      now = System.system_time(:second)
      used = Map.reject(used, fn {_, expires} -> expires <= now end)
      if Map.has_key?(used, jti), do: {:error, used}, else: {:ok, Map.put(used, jti, exp)}
    end)
  end
end
