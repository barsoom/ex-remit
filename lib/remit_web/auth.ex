defmodule RemitWeb.Auth do
  @moduledoc false
  defmodule Routing do
    @moduledoc false
    import Plug.Conn

    def check_auth_key(conn, _opts) do
      given_key = conn.params["auth_key"] || get_session(conn, :auth_key)

      # Keep it in session so we stay authed without having to pass it around, and so LiveViews can access it on mount.
      conn = conn |> put_session(:auth_key, given_key)

      cond do
        given_key == Remit.Config.auth_key() -> conn
        oauth_state_callback?(conn) -> conn
        true -> deny(conn)
      end
    end

    # Lets the OAuth/MCP flow's GitHub-callback round-trip reach the
    # GithubAuthController even when the browser has no auth_key cookie.
    # Restricted to the GitHub callback path so a freshly-minted state
    # JWT can't be repurposed as a general auth_key bypass on unrelated
    # `:browser` or `:api` routes for the duration of its TTL.
    #
    # NOTE: this exemption is sized to the current behavior of `/auth`,
    # which is solely the GitHub OAuth callback (legacy web-login flow +
    # the OAuth/MCP flow dispatched via the JWT-state branch). If `/auth`
    # ever gains unrelated behavior, revisit this — a valid state JWT
    # would otherwise grant unauthenticated access to that new behavior
    # too.
    defp oauth_state_callback?(%{request_path: "/auth"} = conn) do
      with state when is_binary(state) <- conn.params["state"],
           {:ok, _} <- RemitWeb.OAuth.JWT.verify_oauth_state(state) do
        true
      else
        _ -> false
      end
    end

    defp oauth_state_callback?(_conn), do: false

    defp deny(conn) do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(403, "Invalid auth_key")
      |> halt()
    end

    def check_webhook_key(conn, _opts) do
      given_key = conn.params["auth_key"]
      check_key(conn, given_key, Remit.Config.webhook_key())
    end

    # Private

    defp check_key(conn, given_key, expected_key) do
      if given_key == expected_key do
        conn
      else
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(403, "Invalid auth_key")
        |> halt()
      end
    end
  end

  defmodule Controller do
    @moduledoc """
    Common auth helpers. Included in all controllers.
    """
    import Plug.Conn
    alias RemitWeb.OAuth.JWT

    @github_bearer_token_key "github_bearer_token"
    @supported_mcp_protocol_versions ["2025-11-25", "2025-06-18"]

    def github_bearer_token(conn), do: get_session(conn, @github_bearer_token_key)
    def put_github_bearer_token(conn, token), do: put_session(conn, @github_bearer_token_key, token)
    def delete_github_bearer_token(conn), do: delete_session(conn, @github_bearer_token_key)

    def ensure_github_bearer_token(conn, _) do
      if github_bearer_token(conn) do
        conn
      else
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(403, "not logged in with GitHub")
        |> halt()
      end
    end

    @doc """
    Verifies the JWT bearer token (HS256, audience = "remit-mcp") and
    populates `conn.assigns.username` and `conn.assigns.scopes`. On
    failure, returns 401 with an RFC 9728 `WWW-Authenticate` discovery
    hint.
    """
    def authenticate_bearer(conn, _opts) do
      with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
           {:ok, claims} <- JWT.verify_access(token),
           %{"aud" => aud, "sub" => login} <- claims,
           true <- aud == JWT.access_audience() do
        conn
        |> assign(:username, login)
        |> assign(:scopes, String.split(claims["scope"] || "", " ", trim: true))
      else
        _ ->
          conn
          |> put_resp_header("www-authenticate", build_www_authenticate(conn))
          |> put_resp_content_type("application/json")
          |> send_resp(401, Jason.encode!(%{"error" => "invalid_token"}))
          |> halt()
      end
    end

    @doc """
    DNS-rebinding guard. Allowlist sourced from `:remit, :mcp_allowed_origins`.
    Empty `Origin` (curl, CLI) is allowed; mismatched → 403.
    """
    def validate_origin(conn, _opts) do
      case get_req_header(conn, "origin") do
        [] ->
          conn

        [origin | _] ->
          allowed = Application.get_env(:remit, :mcp_allowed_origins, [])

          if origin in allowed do
            conn
          else
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(403, Jason.encode!(%{"error" => "origin_not_allowed"}))
            |> halt()
          end
      end
    end

    @doc """
    When the `MCP-Protocol-Version` header is present, it must be in the
    allowlist. When absent, the request is permitted.
    """
    def validate_protocol_version(conn, _opts) do
      case get_req_header(conn, "mcp-protocol-version") do
        [] ->
          conn

        [version | _] ->
          if version in @supported_mcp_protocol_versions do
            conn
          else
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(400, Jason.encode!(%{"error" => "unsupported_protocol_version"}))
            |> halt()
          end
      end
    end

    defp build_www_authenticate(conn) do
      base = RemitWeb.OAuth.BaseURL.from_conn(conn)
      metadata_url = base <> "/.well-known/oauth-protected-resource/mcp"
      ~s|Bearer realm="mcp", error="invalid_token", resource_metadata="#{metadata_url}"|
    end
  end

  # Based on https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-security-considerations-of-the-liveview-model.
  defmodule LiveView do
    @moduledoc false
    def check_auth_key(session) do
      given_auth_key = session["auth_key"]
      if given_auth_key != Remit.Config.auth_key(), do: throw("Invalid auth_key in LiveView: #{given_auth_key}")
    end
  end

  defmodule Socket do
    @moduledoc false
    def authed_via_socket_params?(%{"auth_key" => given_auth_key}) do
      given_auth_key == Remit.Config.auth_key()
    end
  end
end
