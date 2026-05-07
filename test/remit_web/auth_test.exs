defmodule RemitWeb.AuthTest do
  use RemitWeb.ConnCase
  alias RemitWeb.OAuth.JWT

  describe "check_auth_key bypass for OAuth state" do
    setup do
      {:ok, state_jwt} =
        JWT.sign_oauth_state(%{
          "csrf" => "abc",
          "authorize_params" => %{
            "client_id" => "remit-cli",
            "redirect_uri" => "http://127.0.0.1:55321/callback",
            "code_challenge" => "X",
            "code_challenge_method" => "S256",
            "scope" => "remit:read",
            "state" => "client-state"
          }
        })

      %{state_jwt: state_jwt}
    end

    test "does not bypass auth_key on /api/stats", %{conn: conn, state_jwt: state_jwt} do
      conn = get(conn, "/api/stats?state=#{state_jwt}")
      assert conn.status == 403
    end

    test "does not bypass auth_key on /commits (browser pipeline)", %{conn: conn, state_jwt: state_jwt} do
      conn = get(conn, "/commits?state=#{state_jwt}")
      assert conn.status == 403
    end

    test "allows /auth to proceed to the controller (where the state will be processed)",
         %{conn: conn, state_jwt: state_jwt} do
      conn = get(conn, "/auth?state=#{state_jwt}")
      assert json_response(conn, 400)["error"] == "invalid_request"
    end
  end
end
