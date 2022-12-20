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

  defp put_filter(nil, scope, param, value), do: put_filter(%{}, scope, param, value)
  defp put_filter(filters, scope, param, value) do
    put_in(filters, Enum.map([scope, param], &Access.key(&1, %{})), value)
  end
end
