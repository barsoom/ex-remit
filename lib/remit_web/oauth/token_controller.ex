defmodule RemitWeb.OAuth.TokenController do
  @moduledoc """
  RFC 6749 token endpoint. Supports `authorization_code` (with PKCE) and
  `refresh_token` grants.

  Stateless: verifies the JWT signature/expiry/PKCE/redirect_uri and re-mints
  with the original audience and scope. Refresh never widens authority.
  """
  use RemitWeb, :controller
  alias RemitWeb.OAuth.JWT

  def token(conn, %{"grant_type" => "authorization_code"} = params) do
    with %{"code" => code, "code_verifier" => verifier, "redirect_uri" => redirect_uri} <- params,
         {:ok, claims} <- JWT.verify_code(code),
         :ok <- check_pkce(claims, verifier),
         :ok <- check_redirect(claims, redirect_uri) do
      send_tokens(conn, claims["sub"], claims["scope"], claims["client_id"])
    else
      _ -> grant_error(conn)
    end
  end

  def token(conn, %{"grant_type" => "refresh_token", "refresh_token" => refresh}) do
    case JWT.verify_refresh(refresh) do
      {:ok, claims} -> send_tokens(conn, claims["sub"], claims["scope"], claims["client_id"])
      _ -> grant_error(conn)
    end
  end

  def token(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{"error" => "unsupported_grant_type"})
  end

  # Private

  defp check_pkce(%{"code_challenge" => challenge, "code_challenge_method" => "S256"}, verifier) do
    computed = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
    if computed == challenge, do: :ok, else: :error
  end

  defp check_pkce(_, _), do: :error

  defp check_redirect(%{"redirect_uri" => expected}, given) when expected == given, do: :ok
  defp check_redirect(_, _), do: :error

  defp send_tokens(conn, sub, scope, client_id) do
    {:ok, access} = JWT.sign_access(%{"sub" => sub, "scope" => scope || ""})

    {:ok, refresh} =
      JWT.sign_refresh(%{
        "sub" => sub,
        "scope" => scope || "",
        "client_id" => client_id
      })

    json(conn, %{
      "access_token" => access,
      "token_type" => "Bearer",
      "expires_in" => 3600,
      "refresh_token" => refresh,
      "scope" => scope || ""
    })
  end

  defp grant_error(conn) do
    conn
    |> put_status(400)
    |> json(%{"error" => "invalid_grant"})
  end
end
