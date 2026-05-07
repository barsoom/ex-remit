defmodule RemitWeb.CLI.AuthController do
  use RemitWeb, :controller

  def whoami(conn, _params), do: json(conn, %{username: conn.assigns.username})
end
