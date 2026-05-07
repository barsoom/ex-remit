defmodule RemitWeb.OAuth.WellKnownTest do
  use RemitWeb.ConnCase

  test "GET /.well-known/oauth-authorization-server is reachable without auth_key", %{conn: conn} do
    response =
      conn
      |> get("/.well-known/oauth-authorization-server")
      |> json_response(200)

    assert response["issuer"]
    assert response["authorization_endpoint"] =~ "/oauth/authorize"
    assert response["token_endpoint"] =~ "/oauth/token"
    assert response["registration_endpoint"] =~ "/oauth/register"
    assert "S256" in response["code_challenge_methods_supported"]
    assert "remit:read" in response["scopes_supported"]
    assert "remit:review" in response["scopes_supported"]
  end

  test "GET /.well-known/oauth-protected-resource/mcp", %{conn: conn} do
    response =
      conn
      |> get("/.well-known/oauth-protected-resource/mcp")
      |> json_response(200)

    assert response["resource"] =~ "/mcp"
    assert is_list(response["authorization_servers"])
    assert "header" in response["bearer_methods_supported"]
  end

  test "POST /oauth/register returns synthetic client_id without auth_key", %{conn: conn} do
    response =
      conn
      |> post("/oauth/register", %{
        "redirect_uris" => ["http://127.0.0.1:55321/callback"],
        "client_name" => "test"
      })
      |> json_response(201)

    assert String.starts_with?(response["client_id"], "remit-dcr-")
    assert response["token_endpoint_auth_method"] == "none"
  end
end
