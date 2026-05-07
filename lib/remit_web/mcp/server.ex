defmodule RemitWeb.MCP.Server do
  @moduledoc """
  JSON-RPC dispatcher for the MCP surface. Pinned to a specific
  `protocolVersion`; bumped in lockstep with the request-time
  `MCP-Protocol-Version` allowlist in `RemitWeb.Auth.Controller`.
  """
  alias Remit.Tools

  @protocol_version "2025-11-25"
  @server_info %{name: "remit", version: "0.1.0"}
  @instructions """
  Use this server to drive Remit's GitHub commit review without leaving Claude.

  Typical flow when the user asks "what should I review?":
    1. `list_comments` (defaults to unresolved, for_me) to see review feedback that needs action.
    2. `list_commits` to see unreviewed/reviewed commits in the same feed the web UI shows.
    3. Act with `mark_reviewed`, `start_review`, `mark_unreviewed`, `resolve_comment`, or
       `unresolve_comment`.

  Tool IDs are Remit's database IDs (integers), not GitHub IDs or SHAs.
  """

  def handle(%{"method" => "initialize", "id" => id}, _conn) do
    success(id, %{
      protocolVersion: @protocol_version,
      capabilities: %{tools: %{}},
      serverInfo: @server_info,
      instructions: @instructions
    })
  end

  def handle(%{"method" => "notifications/initialized"}, _conn), do: :no_response

  def handle(%{"method" => "tools/list", "id" => id}, _conn) do
    success(id, %{tools: Enum.map(Tools.list(), &mcp_tool_descriptor/1)})
  end

  def handle(%{"method" => "tools/call", "id" => id, "params" => %{"name" => name} = params}, conn) do
    ctx = %{username: conn.assigns.username, scopes: conn.assigns.scopes}

    case Tools.call(name, Map.get(params, "arguments", %{}), ctx) do
      {:ok, result} ->
        success(id, %{
          # Per the MCP spec (2025-06-18+), `structuredContent` MUST be a
          # JSON object. Wrap bare lists in `%{items: list}`; the `content`
          # text field still carries the natural shape.
          structuredContent: wrap_for_structured_content(result),
          content: [%{type: "text", text: Jason.encode!(result)}],
          isError: false
        })

      {:error, _reason, message} ->
        success(id, %{
          content: [%{type: "text", text: message}],
          isError: true
        })
    end
  end

  def handle(%{"id" => id}, _conn), do: error(id, -32_601, "method not found")
  def handle(_msg, _conn), do: :no_response

  # Private

  defp success(id, result), do: %{jsonrpc: "2.0", id: id, result: result}
  defp error(id, code, message), do: %{jsonrpc: "2.0", id: id, error: %{code: code, message: message}}

  defp mcp_tool_descriptor(%{name: n, input_schema: s, description: d}),
    do: %{name: n, description: d, inputSchema: s}

  defp wrap_for_structured_content(result) when is_list(result), do: %{items: result}
  defp wrap_for_structured_content(result), do: result
end
