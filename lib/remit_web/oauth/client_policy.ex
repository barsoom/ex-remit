defmodule RemitWeb.OAuth.ClientPolicy do
  @moduledoc """
  Uniform policy for every OAuth client (pre-baked, DCR-issued, or arbitrary).

  Stateless DCR means the server cannot distinguish between client_ids, so
  every client gets the same loopback-redirect-URI ceiling and the same
  scope ceiling.
  """

  @scope_ceiling ~w(remit:read remit:review)

  def scope_ceiling, do: @scope_ceiling

  @doc """
  Returns `:ok` if the redirect URI is a loopback URI per RFC 8252 §7.3
  (`http://127.0.0.1:<port>/callback` or `http://localhost:<port>/callback`).
  Port is not pre-validated; loopback host + `/callback` path are required.
  """
  def validate_redirect_uri(uri) when is_binary(uri) do
    case URI.parse(uri) do
      %URI{scheme: "http", host: host, path: "/callback", port: port}
      when host in ["127.0.0.1", "localhost"] and is_integer(port) ->
        :ok

      _ ->
        :error
    end
  end

  def validate_redirect_uri(_), do: :error

  @doc """
  Returns the intersection of the requested scopes (space-separated) with
  the org-wide ceiling, as a space-separated string.
  """
  def intersect_scope(requested) when is_binary(requested) do
    requested
    |> String.split(" ", trim: true)
    |> Enum.filter(&(&1 in @scope_ceiling))
    |> Enum.join(" ")
  end

  def intersect_scope(nil), do: ""
end
