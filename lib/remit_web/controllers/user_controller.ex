defmodule RemitWeb.UserController do
  use RemitWeb, :controller

  plug :accepts, ["json"]

  @spec set_filter_preference(Plug.Conn.t(), any) :: Plug.Conn.t()
  def set_filter_preference(conn, %{"scope" => scope, "param" => param, "value" => value}) do
    stored_filter = get_session(conn, "filter")

    conn
    |> put_session("filter", put_filter(stored_filter, scope, param, value))
    |> json(true)
  end

  def set_reviewed_commit_cutoff(conn, %{"reviewed_commit_cutoff" => cutoff}) do
    stored_cutoff = get_session(conn, "reviewed_commit_cutoff") || %{}

    conn
    |> put_session("reviewed_commit_cutoff", put_reviewed_commit_cutoff(stored_cutoff, cutoff))
    |> json(true)
  end

  defp put_filter(nil, scope, param, value), do: put_filter(%{}, scope, param, value)

  defp put_filter(filters, scope, param, value) do
    put_in(filters, Enum.map([scope, param], &Access.key(&1, %{})), value)
  end

  defp put_reviewed_commit_cutoff(cutoff, new_cutoff) do
    new_cutoff
    |> Enum.reduce(cutoff, fn {key, value}, acc ->
      put_reviewed_commit_cutoff(acc, key, value)
    end)
  end

  defp put_reviewed_commit_cutoff(cutoff, "days" = key, value), do: Map.put(cutoff, key, String.to_integer(value))
  defp put_reviewed_commit_cutoff(cutoff, "commits" = key, value), do: Map.put(cutoff, key, String.to_integer(value))
end
