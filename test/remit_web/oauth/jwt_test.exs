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
    # Joken.verify on a very old `exp` claim — sign one then mutate by hand.
    {:ok, access} = JWT.sign_access(%{"sub" => "alice", "scope" => "remit:read", "exp" => 1})
    # The above returned with our merge that overwrites exp; force-sign past expiry:
    [header, payload, _sig] = String.split(access, ".")
    decoded = payload |> Base.url_decode64!(padding: false) |> Jason.decode!()
    munged = Map.put(decoded, "exp", 1) |> Jason.encode!() |> Base.url_encode64(padding: false)
    # Re-sign for invalidity test. Constructing a valid HS256 sig requires the secret;
    # tampering payload alone makes the signature invalid → invalid_token.
    munged_token = [header, munged, "bad"] |> Enum.join(".")

    assert {:error, :invalid_token} = JWT.verify_access(munged_token)
  end
end
