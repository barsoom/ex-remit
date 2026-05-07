defmodule RemitWeb.OAuth.JWT do
  @moduledoc """
  Sign and verify the four token types used by the OAuth surface.

  Tokens are RFC-7519 JWTs (HS256) signed with a key derived from
  `secret_key_base`. Sign + verify are pure HMAC: no DB lookup, no
  GitHub round-trip, no cache.
  """
  use Joken.Config, default_signer: nil

  @issuer "remit"
  @access_audience "remit-mcp"

  @code_ttl 60
  @access_ttl 60 * 60
  @refresh_ttl 7 * 24 * 60 * 60
  @oauth_state_ttl 5 * 60

  def access_audience, do: @access_audience

  def sign_code(claims), do: sign("remit+code", claims, @code_ttl)
  def sign_access(claims), do: sign("remit+access", Map.put(claims, "aud", @access_audience), @access_ttl)
  def sign_refresh(claims), do: sign("remit+refresh", Map.put(claims, "aud", @access_audience), @refresh_ttl)
  def sign_oauth_state(claims), do: sign("remit+state", claims, @oauth_state_ttl)

  def verify_code(token), do: verify(token, "remit+code")
  def verify_access(token), do: verify(token, "remit+access")
  def verify_refresh(token), do: verify(token, "remit+refresh")
  def verify_oauth_state(token), do: verify(token, "remit+state")

  # Private

  defp sign(type, claims, ttl) do
    now = System.system_time(:second)

    payload =
      claims
      |> Map.merge(%{
        "iss" => @issuer,
        "iat" => now,
        "exp" => now + ttl,
        "typ" => type
      })

    Joken.Signer.sign(payload, signer())
  end

  defp verify(token, expected_type) do
    with {:ok, claims} <- Joken.verify(token, signer()),
         %{"typ" => ^expected_type, "iss" => @issuer, "exp" => exp} <- claims,
         true <- exp > System.system_time(:second) do
      {:ok, claims}
    else
      _ -> {:error, :invalid_token}
    end
  end

  defp signer do
    Joken.Signer.create("HS256", secret())
  end

  defp secret do
    config = Application.fetch_env!(:remit, RemitWeb.Endpoint)
    base = Keyword.fetch!(config, :secret_key_base)
    :crypto.hash(:sha256, ["remit-oauth-jwt:", base]) |> Base.url_encode64(padding: false)
  end
end
