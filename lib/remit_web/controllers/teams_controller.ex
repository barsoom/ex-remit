defmodule RemitWeb.TeamsController do
  use RemitWeb, :controller

  plug :ensure_github_bearer_token

  def update(conn, _) do
    ok = Remit.Team.update_from_github(github_bearer_token(conn))
    conn |> json(ok)
  end
end
