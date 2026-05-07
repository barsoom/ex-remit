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
      # We don't assert success here — the GitHub-code exchange will fail
      # without a real `code`. We assert only that the request was NOT
      # halted by check_auth_key with 403 "Invalid auth_key".
      refute conn.status == 403
    end
  end
end
