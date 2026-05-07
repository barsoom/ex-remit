defmodule Remit.CLI.Client do
  @moduledoc """
  HTTP client for `./remit`. Loads credentials from
  `~/.config/remit/credentials`, refreshes the access token if it's about
  to expire, and dispatches a single REST call.
  """

  @credentials_subpath ".config/remit/credentials"

  def credentials_path do
    Path.join(System.user_home!(), @credentials_subpath)
  end

  def load_credentials! do
    path = credentials_path()

    case File.read(path) do
      {:ok, raw} ->
        case Jason.decode(raw) do
          {:ok, %{} = creds} -> creds
          _ -> raise "credentials file at #{path} is not valid JSON"
        end

      {:error, :enoent} ->
        raise "not logged in (run `./remit login` first)"
    end
  end

  def save_credentials!(creds) do
    path = credentials_path()
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(creds))
    File.chmod!(path, 0o600)
  end

  def delete_credentials! do
    path = credentials_path()

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> raise "could not delete credentials: #{inspect(reason)}"
    end
  end

  def request!(method, path, body \\ nil) do
    creds = ensure_fresh!(load_credentials!())
    url = creds["base_url"] <> path

    headers = [
      {~c"authorization", String.to_charlist("Bearer " <> creds["access_token"])},
      {~c"accept", ~c"application/json"}
    ]

    request =
      case method do
        :get -> {String.to_charlist(url), headers}
        :post -> {String.to_charlist(url), headers, ~c"application/json", body || ~c""}
      end

    :inets.start()
    :ssl.start()

    case :httpc.request(method, request, [], body_format: :binary) do
      {:ok, {{_, status, _}, _hdrs, body}} -> {status, decode_body(body)}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private

  defp ensure_fresh!(creds) do
    expires_at = creds["expires_at"] || 0

    if expires_at - System.system_time(:second) < 60 do
      refreshed = refresh!(creds)
      save_credentials!(refreshed)
      refreshed
    else
      creds
    end
  end

  defp refresh!(creds) do
    body =
      URI.encode_query(%{
        "grant_type" => "refresh_token",
        "refresh_token" => creds["refresh_token"]
      })

    headers = [{~c"content-type", ~c"application/x-www-form-urlencoded"}]
    url = String.to_charlist(creds["base_url"] <> "/oauth/token")

    :inets.start()
    :ssl.start()

    case :httpc.request(:post, {url, headers, ~c"application/x-www-form-urlencoded", body}, [], body_format: :binary) do
      {:ok, {{_, 200, _}, _, raw}} ->
        decoded = Jason.decode!(raw)

        Map.merge(creds, %{
          "access_token" => decoded["access_token"],
          "refresh_token" => decoded["refresh_token"] || creds["refresh_token"],
          "expires_at" => System.system_time(:second) + (decoded["expires_in"] || 3600)
        })

      _ ->
        raise "refresh failed; run `./remit login` again"
    end
  end

  defp decode_body(""), do: nil

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{"raw_body" => String.slice(body, 0, 500)}
    end
  end
end
