defmodule RemitWeb.Plugs do
  @moduledoc """
  Small function plugs that do not merit a whole module.
  """

  import Plug.Conn

  def ensure_session_id(conn, _) do
    case get_session(conn, "session_id") do
      nil ->
        conn
        |> put_session("session_id", Ecto.UUID.generate())

      _ ->
        conn
    end
  end
end
