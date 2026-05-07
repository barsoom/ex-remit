defmodule RemitWeb.OAuth.JWTTest do
  use ExUnit.Case, async: true
  alias RemitWeb.OAuth.JWT

  test "round-trips each token type" do
    {:ok, code} = JWT.sign_code(%{"sub" => "alice", "client_id" => "remit-cli"})
    {:ok, access} = JWT.sign_access(%{"sub" => "alice", "scope" => "remit:read"})
    {:ok, refresh} = JWT.sign_refresh(%{"sub" => "alice", "scope" => "remit:read", "client_id" => "remit-cli"})
    {:ok, state} = JWT.sign_oauth_state(%{"csrf" => "abc"})

    assert {:ok, %{"sub" => "alice", "typ" => "remit+code"}} = JWT.verify_code(code)
    assert {:ok, %{"sub" => "alice", "typ" => "remit+access", "aud" => "remit-mcp"}} = JWT.verify_access(access)
    assert {:ok, %{"sub" => "alice", "typ" => "remit+refresh", "aud" => "remit-mcp"}} = JWT.verify_refresh(refresh)
    assert {:ok, %{"csrf" => "abc", "typ" => "remit+state"}} = JWT.verify_oauth_state(state)
  end

  test "tampered token rejected" do
    {:ok, access} = JWT.sign_access(%{"sub" => "alice", "scope" => "remit:read"})
    tampered = access <> "x"

    assert {:error, :invalid_token} = JWT.verify_access(tampered)
  end

  test "wrong-type verification rejected" do
    {:ok, code} = JWT.sign_code(%{"sub" => "alice"})
    assert {:error, :invalid_token} = JWT.verify_access(code)
  end

  test "expired token rejected" do
    {:ok, access} = JWT.sign_access(%{"sub" => "alice", "scope" => "remit:read"})
    {:ok, claims} = JWT.verify_access(access)
    {:ok, expired} = Joken.Signer.sign(%{claims | "exp" => System.system_time(:second) - 1}, signer())

    assert {:ok, _} = Joken.verify(expired, signer())
    assert {:error, :invalid_token} = JWT.verify_access(expired)
  end

  defp signer do
    base = Application.fetch_env!(:remit, RemitWeb.Endpoint)[:secret_key_base]
    Joken.Signer.create("HS256", :crypto.hash(:sha256, ["remit-oauth-jwt:", base]) |> Base.url_encode64(padding: false))
  end
end
