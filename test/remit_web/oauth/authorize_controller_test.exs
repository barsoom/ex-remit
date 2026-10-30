defmodule RemitWeb.OAuth.AuthorizeControllerTest do
  use RemitWeb.ConnCase
  import Mox
  alias RemitWeb.OAuth.JWT

  @good_redirect "http://127.0.0.1:55321/callback"
  @good_challenge "FAKE-CHALLENGE"

  setup :verify_on_exit!

  setup do
    original = Application.get_env(:remit, :github_org_slug)
    Application.put_env(:remit, :github_org_slug, "acme")
    on_exit(fn -> Application.put_env(:remit, :github_org_slug, original) end)
  end

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

  test "unauthenticated user is handed off to GitHub with a state JWT, without needing auth_key", %{conn: conn} do
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
    assert get_session(conn, "oauth_csrf") == claims["csrf"]
  end

  test "session with a GitHub user but no GitHub token is handed off to GitHub", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{"github_user" => %Remit.Github.User{login: "alice"}})
      |> get("/oauth/authorize?" <> URI.encode_query(authorize_query()))

    assert redirected_to(conn, 302) =~ "github.com/login/oauth/authorize"
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

  describe "with a GitHub session" do
    test "org member is redirected to redirect_uri with a code", %{conn: conn} do
      expect_membership_check("alice-gh-token", :active)
      conn = authorize_with_session(conn, authorize_query())

      location = redirected_to(conn, 302)
      assert String.starts_with?(location, @good_redirect)

      %URI{query: q} = URI.parse(location)
      decoded = URI.decode_query(q)

      assert decoded["state"] == "client-state-123"
      {:ok, claims} = JWT.verify_code(decoded["code"])
      assert claims["sub"] == "alice"
      assert claims["scope"] == "remit:read remit:review"
    end

    test "scope is intersected with the ceiling", %{conn: conn} do
      expect_membership_check("alice-gh-token", :active)
      conn = authorize_with_session(conn, authorize_query(%{"scope" => "remit:read remit:admin"}))

      %URI{query: q} = URI.parse(redirected_to(conn, 302))
      {:ok, claims} = JWT.verify_code(URI.decode_query(q)["code"])

      assert claims["scope"] == "remit:read"
    end

    test "non-member is sent back to the client with access_denied", %{conn: conn} do
      expect_membership_check("alice-gh-token", :inactive)
      conn = authorize_with_session(conn, authorize_query())

      assert %{"error" => "access_denied", "error_description" => description, "state" => "client-state-123"} =
               callback_params(conn)

      assert description =~ "not a member of the acme GitHub organization"
      refute Map.has_key?(callback_params(conn), "code")
    end

    test "a GitHub token GitHub no longer accepts sends the user through GitHub login again", %{conn: conn} do
      expect_membership_check("alice-gh-token", :bad_token)
      conn = authorize_with_session(conn, authorize_query())

      assert redirected_to(conn, 302) =~ "github.com/login/oauth/authorize"
    end

    test "no configured GitHub org is denied without asking GitHub", %{conn: conn} do
      Application.put_env(:remit, :github_org_slug, "")
      conn = authorize_with_session(conn, authorize_query())

      assert %{"error" => "access_denied", "error_description" => "Remit has no GitHub organization configured"} =
               callback_params(conn)
    end
  end

  describe "GitHub callback" do
    setup do
      Tesla.Mock.mock(fn
        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          Tesla.Mock.json(%{"access_token" => "bob-gh-token"})

        %{method: :get, url: "https://api.github.com/user"} ->
          Tesla.Mock.json(%{"login" => "bob"})
      end)

      handoff = get(build_conn(), "/oauth/authorize?" <> URI.encode_query(authorize_query()))
      %URI{query: q} = URI.parse(redirected_to(handoff, 302))
      %{state: URI.decode_query(q)["state"], csrf: get_session(handoff, "oauth_csrf")}
    end

    test "org member gets a code for the original authorize request", %{conn: conn, state: state, csrf: csrf} do
      expect_membership_check("bob-gh-token", :active)
      conn = github_callback(conn, %{"oauth_csrf" => csrf}, state)

      %URI{query: q} = URI.parse(redirected_to(conn, 302))
      {:ok, claims} = JWT.verify_code(URI.decode_query(q)["code"])

      assert claims["sub"] == "bob"
      assert get_session(conn, "github_bearer_token") == "bob-gh-token"
      assert get_session(conn, "oauth_csrf") == nil
    end

    test "non-member is sent back to the client with access_denied", %{conn: conn, state: state, csrf: csrf} do
      expect_membership_check("bob-gh-token", :inactive)
      conn = github_callback(conn, %{"oauth_csrf" => csrf}, state)

      assert %{"error" => "access_denied", "state" => "client-state-123"} = callback_params(conn)
    end

    test "a state started in another browser is rejected without touching the session", %{conn: conn, state: state} do
      for session <- [%{}, %{"oauth_csrf" => "other"}] do
        conn = github_callback(conn, Map.put(session, "github_user", %Remit.Github.User{login: "victim"}), state)

        assert json_response(conn, 400)["error"] == "invalid_state"
        assert get_session(conn, "github_user") == %Remit.Github.User{login: "victim"}
        assert get_session(conn, "github_bearer_token") == nil
        assert get_session(conn, "oauth_csrf") == nil
      end
    end
  end

  defp github_callback(conn, session, state) do
    conn
    |> Plug.Test.init_test_session(session)
    |> get("/auth?" <> URI.encode_query(%{"code" => "gh-code", "state" => state}))
  end

  defp callback_params(conn) do
    %URI{query: q} = URI.parse(redirected_to(conn, 302))
    URI.decode_query(q)
  end

  defp authorize_with_session(conn, query) do
    conn
    |> Plug.Test.init_test_session(%{
      "github_user" => %Remit.Github.User{login: "alice"},
      "github_bearer_token" => "alice-gh-token"
    })
    |> get("/oauth/authorize?" <> URI.encode_query(query))
  end

  defp expect_membership_check(token, membership) do
    expect(GitHubAPIClient.Mock, :org_membership, fn ^token, "acme" -> membership end)
  end
end
