defmodule RemitWeb.GithubAuthController do
  use RemitWeb, :controller
  alias Remit.GithubAuth
  alias Remit.GitHubAPIClient

  def login(conn, _params) do
    token = GithubAuth.create_state_token()

    conn
    |> put_session("github_state_token", token)
    |> redirect(external: GithubAuth.auth_url(token))
  end

  # redirect callback
  def auth(conn, params) do
    conn
    |> verify_state(params)
    |> get_access_token_and_user(params)
    |> broadcast_login()
    |> redirect(to: ~p"/settings")
  end

  def logout(conn, _) do
    conn
    |> delete_github_bearer_token()
    |> delete_session("github_user")
    |> broadcast_logout()
    |> json(true)
  end

  defp verify_state(conn, %{"state" => token}) do
    if get_session(conn, "github_state_token") == token && GithubAuth.verify_and_destroy_state_token(token) do
      conn
      |> delete_session("github_state_token")
    else
      conn
      |> send_resp(:forbidden, "invalid oauth state")
      |> halt()
    end
  end

  defp get_access_token_and_user(conn, %{"code" => code}) do
    token = GithubAuth.get_access_token(code)

    conn
    |> put_github_bearer_token(token)
    |> put_session("github_user", GitHubAPIClient.get_user(token))
  end

  defp broadcast_login(conn) do
    # try to avoid broadcasting the token here:
    # it creates unnecessary temptation to do (slow) github API calls from the liveview context, so it's best not to give it the means to do so
    GithubAuth.broadcast_login(get_session(conn, "session_id"), get_session(conn, "github_user"))

    conn
  end

  defp broadcast_logout(conn) do
    GithubAuth.broadcast_logout(get_session(conn, "session_id"))

    conn
  end
end
