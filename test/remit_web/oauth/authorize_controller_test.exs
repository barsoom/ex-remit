defmodule RemitWeb.OAuth.AuthorizeControllerTest do
  use RemitWeb.ConnCase
  alias RemitWeb.OAuth.JWT

  @good_redirect "http://127.0.0.1:55321/callback"
  @good_challenge "FAKE-CHALLENGE"

  defp authorize_query(overrides \\ %{}) do
    Map.merge(
      %{
        "response_type" => "code",
        "client_id" => "remit-cli",
        "redirect_uri" => @good_redirect,
        "code_challenge" => @good_challenge,
        "code_challenge_method" => "S256",
        "scope" => "remit:read remit:review",
        "state" => "client-state-123"
      },
      overrides
    )
  end

  test "OAuth pipeline does not require auth_key (no session has it)", %{conn: conn} do
    conn = get(conn, "/oauth/authorize?" <> URI.encode_query(authorize_query()))
    # Either we get a redirect or we get a 4xx — but never 403 (which would
    # mean check_auth_key was on the path).
    refute conn.status == 403
  end

  test "unauthenticated user is handed off to GitHub with a state JWT", %{conn: conn} do
    conn = get(conn, "/oauth/authorize?" <> URI.encode_query(authorize_query()))

    assert conn.status == 302
    location = Plug.Conn.get_resp_header(conn, "location") |> List.first()

    assert location =~ "github.com/login/oauth/authorize"

    %URI{query: q} = URI.parse(location)
    state = URI.decode_query(q)["state"]

    {:ok, claims} = JWT.verify_oauth_state(state)

    assert claims["authorize_params"]["client_id"] == "remit-cli"
    assert claims["authorize_params"]["redirect_uri"] == @good_redirect
    assert is_binary(claims["csrf"])
  end

  test "non-loopback redirect_uri returns 400 (not a 302)", %{conn: conn} do
    conn =
      get(
        conn,
        "/oauth/authorize?" <>
          URI.encode_query(authorize_query(%{"redirect_uri" => "https://evil.example.com/callback"}))
      )

    assert conn.status == 400
    body = json_response(conn, 400)
    assert body["error"] == "invalid_request"
  end

  test "non-S256 code_challenge_method returns 400", %{conn: conn} do
    conn =
      get(
        conn,
        "/oauth/authorize?" <>
          URI.encode_query(authorize_query(%{"code_challenge_method" => "plain"}))
      )

    assert conn.status == 400
  end

  test "already-authenticated session redirects directly to redirect_uri", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session("github_user", %Remit.Github.User{login: "alice"})
      |> get("/oauth/authorize?" <> URI.encode_query(authorize_query()))

    assert conn.status == 302
    location = Plug.Conn.get_resp_header(conn, "location") |> List.first()
    assert String.starts_with?(location, @good_redirect)

    %URI{query: q} = URI.parse(location)
    decoded = URI.decode_query(q)

    assert decoded["state"] == "client-state-123"
    {:ok, claims} = JWT.verify_code(decoded["code"])
    assert claims["sub"] == "alice"
    assert claims["scope"] == "remit:read remit:review"
  end

  test "scope is intersected with the ceiling", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session("github_user", %Remit.Github.User{login: "alice"})
      |> get(
        "/oauth/authorize?" <>
          URI.encode_query(authorize_query(%{"scope" => "remit:read remit:admin"}))
      )

    location = Plug.Conn.get_resp_header(conn, "location") |> List.first()
    %URI{query: q} = URI.parse(location)
    {:ok, claims} = JWT.verify_code(URI.decode_query(q)["code"])

    assert claims["scope"] == "remit:read"
  end
end
