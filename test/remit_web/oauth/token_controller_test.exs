defmodule RemitWeb.OAuth.TokenControllerTest do
  use RemitWeb.ConnCase
  alias RemitWeb.OAuth.JWT

  @redirect_uri "http://127.0.0.1:55321/callback"

  defp pkce_pair do
    verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
    {verifier, challenge}
  end

  defp issue_code(scope, redirect_uri \\ @redirect_uri, client_id \\ "remit-cli") do
    {verifier, challenge} = pkce_pair()

    {:ok, code} =
      JWT.sign_code(%{
        "sub" => "alice",
        "client_id" => client_id,
        "redirect_uri" => redirect_uri,
        "code_challenge" => challenge,
        "code_challenge_method" => "S256",
        "scope" => scope
      })

    {code, verifier}
  end

  test "auth-code grant happy path returns access + refresh", %{conn: conn} do
    {code, verifier} = issue_code("remit:read remit:review")

    response =
      conn
      |> post("/oauth/token", %{
        "grant_type" => "authorization_code",
        "code" => code,
        "code_verifier" => verifier,
        "redirect_uri" => @redirect_uri,
        "client_id" => "remit-cli"
      })
      |> json_response(200)

    assert response["token_type"] == "Bearer"
    assert response["expires_in"] == 3600
    assert is_binary(response["access_token"])
    assert is_binary(response["refresh_token"])

    {:ok, claims} = JWT.verify_access(response["access_token"])
    assert claims["sub"] == "alice"
    assert claims["scope"] == "remit:read remit:review"
    assert claims["aud"] == "remit-mcp"
  end

  test "PKCE mismatch returns 400 invalid_grant", %{conn: conn} do
    {code, _} = issue_code("remit:read")

    response =
      conn
      |> post("/oauth/token", %{
        "grant_type" => "authorization_code",
        "code" => code,
        "code_verifier" => "wrong-verifier",
        "redirect_uri" => @redirect_uri,
        "client_id" => "remit-cli"
      })

    assert response.status == 400
    assert json_response(response, 400) == %{"error" => "invalid_grant"}
  end

  test "redirect_uri mismatch returns 400", %{conn: conn} do
    {code, verifier} = issue_code("remit:read")

    response =
      conn
      |> post("/oauth/token", %{
        "grant_type" => "authorization_code",
        "code" => code,
        "code_verifier" => verifier,
        "redirect_uri" => "http://127.0.0.1:99999/callback",
        "client_id" => "remit-cli"
      })

    assert response.status == 400
  end

  test "refresh-token grant preserves scope and audience", %{conn: conn} do
    {:ok, refresh} =
      JWT.sign_refresh(%{"sub" => "alice", "scope" => "remit:read", "client_id" => "remit-cli"})

    response =
      conn
      |> post("/oauth/token", %{"grant_type" => "refresh_token", "refresh_token" => refresh})
      |> json_response(200)

    {:ok, claims} = JWT.verify_access(response["access_token"])

    assert claims["scope"] == "remit:read"
    assert claims["aud"] == "remit-mcp"
  end

  test "unsupported grant returns 400", %{conn: conn} do
    response =
      conn
      |> post("/oauth/token", %{"grant_type" => "password"})

    assert response.status == 400
  end
end
