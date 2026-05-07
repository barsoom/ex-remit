defmodule RemitWeb.OAuth.AuthServerController do
  @moduledoc """
  RFC 8414 Authorization Server metadata.
  """
  use RemitWeb, :controller
  alias RemitWeb.OAuth.ClientPolicy

  def show(conn, _params) do
    issuer = RemitWeb.OAuth.BaseURL.from_conn(conn)

    json(conn, %{
      "issuer" => issuer,
      "authorization_endpoint" => issuer <> "/oauth/authorize",
      "token_endpoint" => issuer <> "/oauth/token",
      "registration_endpoint" => issuer <> "/oauth/register",
      "response_types_supported" => ["code"],
      "grant_types_supported" => ["authorization_code", "refresh_token"],
      "code_challenge_methods_supported" => ["S256"],
      "token_endpoint_auth_methods_supported" => ["none"],
      "scopes_supported" => ClientPolicy.scope_ceiling()
    })
  end
end
