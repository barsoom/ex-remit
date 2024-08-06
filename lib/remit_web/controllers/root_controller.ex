defmodule RemitWeb.RootController do
  use RemitWeb, :controller

  def revision(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, System.get_env("REVISION", "no revision is set"))
  end
end
