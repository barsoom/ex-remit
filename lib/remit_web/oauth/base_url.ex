defmodule RemitWeb.OAuth.BaseURL do
  @moduledoc """
  Derives the public base URL from the inbound request, so OAuth/MCP
  metadata advertises the host the client actually used (e.g.
  `http://devbox:45361`) rather than whatever's in the static endpoint
  config (`http://localhost:45361` in dev).

  The MCP SDK's protected-resource check rejects mismatches between the
  configured `resource` URL and the URL it dialed, so this matters.
  """

  def from_conn(%Plug.Conn{} = conn) do
    scheme = Atom.to_string(conn.scheme)
    host = conn.host
    port = conn.port

    if default_port?(scheme, port) do
      "#{scheme}://#{host}"
    else
      "#{scheme}://#{host}:#{port}"
    end
  end

  defp default_port?("http", 80), do: true
  defp default_port?("https", 443), do: true
  defp default_port?(_, _), do: false
end
