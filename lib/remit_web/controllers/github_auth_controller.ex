defmodule RemitWeb.GithubAuthController do
  use RemitWeb, :controller
  alias Remit.GithubAuth
  alias Remit.GitHubAPIClient

  def login(conn, _params) do
    token = GithubAuth.create_state_token()

    conn
    |> put_session(:github_state_token, token)
    |> redirect(external: GithubAuth.auth_url(token))
  end

  # redirect callback
  def auth(conn, params) do
    conn
    |> verify_state(params)
    |> get_access_token_and_user(params)
    |> redirect(to: Routes.tabs_path(conn, :settings))
  end

  defp verify_state(conn, %{"state" => token}) do
    if get_session(conn, :github_state_token) == token && GithubAuth.verify_and_destroy_state_token(token) do
      conn
      |> delete_session(:github_state_token)
    else
      conn
      |> send_resp(:forbidden, "invalid oauth state")
      |> halt()
    end
  end

  defp get_access_token_and_user(conn, %{"code" => code}) do
    token = GithubAuth.get_access_token(code)

    conn
    |> put_session(:github_bearer_token, token)
    |> put_session(:github_user, GitHubAPIClient.get_user(token))
  end
end
