defmodule RemitWeb.SessionController do
  use RemitWeb, :controller

  def set(conn, %{"email" => email}), do: store_string(conn, :email, email)
  def set(conn, %{"username" => username}), do: store_string(conn, :username, username)

  defp store_string(conn, key, value) do
    conn
    |> put_session(key, Remit.Utils.normalize_string(value))
    |> json("OK!")
  end
end
