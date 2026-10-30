defmodule RemitWeb.OAuth.AuthorizeController do
  @moduledoc """
  Browser-facing OAuth surface.

    - `GET /oauth/authorize`: validates the request, hands off to GitHub if
      the user has no GitHub session, then issues an auth-code JWT to
      members of the configured GitHub org.
    - `github_callback/2`: helper invoked by `GithubAuthController.auth/2`
      when the GitHub `state` parameter is an OAuth-flow JWT. Verifies the
      state and that this browser started the flow, exchanges the code, stashes the user, then resumes the
      original `/oauth/authorize` request from the JWT payload.
  """
  use RemitWeb, :controller
  alias RemitWeb.OAuth.{ClientPolicy, JWT}
  alias Remit.{GithubAuth, GitHubAPIClient}

  @github_client Application.compile_env(:remit, :github_api_client)
  @required_authorize_params ~w(response_type client_id redirect_uri code_challenge code_challenge_method)

  def authorize(conn, params) do
    case validate_authorize_params(params) do
      {:ok, validated} ->
        case {get_session(conn, "github_user"), github_bearer_token(conn)} do
          {%Remit.Github.User{login: login}, token} when is_binary(login) and is_binary(token) ->
            issue_code_to_org_member(conn, validated, login, token)

          _ ->
            handoff_to_github(conn, validated)
        end

      {:error, code, msg} ->
        conn
        |> put_status(400)
        |> json(%{"error" => Atom.to_string(code), "error_description" => msg})
    end
  end

  def github_callback(conn, %{"code" => github_code, "state" => state_token}) do
    expected_csrf = get_session(conn, "oauth_csrf")
    conn = delete_session(conn, "oauth_csrf")

    with {:ok, %{"csrf" => csrf, "authorize_params" => validated}} <- JWT.verify_oauth_state(state_token),
         true <- is_binary(expected_csrf) and Plug.Crypto.secure_compare(csrf, expected_csrf),
         token when is_binary(token) <- GithubAuth.get_access_token(github_code),
         %Remit.Github.User{login: login} = user when is_binary(login) <-
           GitHubAPIClient.get_user(token) do
      conn
      |> put_github_bearer_token(token)
      |> put_session("github_user", user)
      |> issue_code_to_org_member(validated, login, token)
    else
      _ ->
        conn
        |> put_status(400)
        |> json(%{"error" => "invalid_state", "error_description" => "stale or invalid state"})
    end
  end

  def github_callback(conn, _) do
    conn
    |> put_status(400)
    |> json(%{"error" => "invalid_request", "error_description" => "missing code or state"})
  end

  # Private

  defp validate_authorize_params(params) do
    cond do
      not Enum.all?(@required_authorize_params, &Map.has_key?(params, &1)) ->
        {:error, :invalid_request, "missing required authorize parameter"}

      params["response_type"] != "code" ->
        {:error, :unsupported_response_type, "only response_type=code is supported"}

      params["code_challenge_method"] != "S256" ->
        {:error, :invalid_request, "code_challenge_method must be S256"}

      ClientPolicy.validate_redirect_uri(params["redirect_uri"]) != :ok ->
        {:error, :invalid_request, "redirect_uri must be a loopback URI ending in /callback"}

      true ->
        {:ok,
         %{
           "client_id" => params["client_id"],
           "redirect_uri" => params["redirect_uri"],
           "code_challenge" => params["code_challenge"],
           "code_challenge_method" => params["code_challenge_method"],
           "scope" => Map.get(params, "scope", ""),
           "state" => Map.get(params, "state", "")
         }}
    end
  end

  defp handoff_to_github(conn, validated) do
    csrf = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    {:ok, state_jwt} =
      JWT.sign_oauth_state(%{
        "csrf" => csrf,
        "authorize_params" => validated
      })

    conn
    |> put_session("oauth_csrf", csrf)
    |> redirect(external: GithubAuth.auth_url(state_jwt))
  end

  defp issue_code_to_org_member(conn, validated, login, token) do
    org = Remit.Config.github_org_slug()

    if Remit.Config.has_github_org?() do
      case @github_client.org_membership(token, org) do
        :active -> issue_code_redirect(conn, validated, login)
        :bad_token -> handoff_to_github(conn, validated)
        :inactive -> access_denied(conn, validated, "#{login} is not a member of the #{org} GitHub organization")
      end
    else
      access_denied(conn, validated, "Remit has no GitHub organization configured")
    end
  end

  defp access_denied(conn, validated, description) do
    params = %{"error" => "access_denied", "error_description" => description, "state" => validated["state"]}
    redirect(conn, external: build_callback_url(validated["redirect_uri"], params))
  end

  defp issue_code_redirect(conn, validated, login) do
    granted_scope = ClientPolicy.intersect_scope(validated["scope"])

    {:ok, code} =
      JWT.sign_code(%{
        "sub" => login,
        "client_id" => validated["client_id"],
        "redirect_uri" => validated["redirect_uri"],
        "code_challenge" => validated["code_challenge"],
        "code_challenge_method" => validated["code_challenge_method"],
        "scope" => granted_scope
      })

    callback = build_callback_url(validated["redirect_uri"], %{"code" => code, "state" => validated["state"]})
    redirect(conn, external: callback)
  end

  defp build_callback_url(redirect_uri, params) do
    query = URI.encode_query(params)
    sep = if String.contains?(redirect_uri, "?"), do: "&", else: "?"
    redirect_uri <> sep <> query
  end
end
