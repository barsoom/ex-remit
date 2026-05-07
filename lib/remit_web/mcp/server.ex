defmodule RemitWeb.MCP.Server do
  @moduledoc """
  JSON-RPC dispatcher for the MCP surface.
  """
  alias Remit.Tools

  @supported_protocol_versions ["2025-11-25", "2025-06-18"]
  @server_info %{name: "remit", version: "0.1.0"}
  @instructions """
  Use this server to drive Remit's GitHub commit review without leaving Claude.

  Typical flow when the user asks "what should I review?":
    1. `list_comments` (defaults to unresolved, for_me) to see review feedback that needs action.
    2. `list_commits` to see unreviewed/reviewed commits in the same feed the web UI shows.
    3. Act with `mark_reviewed`, `start_review`, `mark_unreviewed`, `resolve_comment`, or
       `unresolve_comment`.

  Commit tools take a Remit commit ID (integer) or a SHA prefix. Comment tools take the Remit
  comment notification ID (integer) from `list_comments`, not a GitHub comment ID.
  """

  def supported_protocol_versions, do: @supported_protocol_versions

  def handle(%{"method" => "initialize", "id" => id} = msg, _conn) do
    requested = get_in(msg, ["params", "protocolVersion"])

    success(id, %{
      protocolVersion:
        if(requested in @supported_protocol_versions, do: requested, else: hd(@supported_protocol_versions)),
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
    case Map.get(params, "arguments", %{}) do
      args when is_map(args) -> call_tool(id, name, args, conn)
      _ -> error(id, -32_602, "arguments must be an object")
    end
  end

  def handle(%{"id" => id}, _conn), do: error(id, -32_601, "method not found")
  def handle(_msg, _conn), do: :no_response

  # Private

  defp call_tool(id, name, args, conn) do
    ctx = %{username: conn.assigns.username, scopes: conn.assigns.scopes}

    case Tools.call(name, args, ctx) do
      {:ok, result} ->
        success(id, %{
          # The MCP spec requires structuredContent to be a JSON object, so lists get wrapped.
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

  defp success(id, result), do: %{jsonrpc: "2.0", id: id, result: result}
  defp error(id, code, message), do: %{jsonrpc: "2.0", id: id, error: %{code: code, message: message}}

  defp mcp_tool_descriptor(%{name: n, input_schema: s, description: d}),
    do: %{name: n, description: d, inputSchema: s}

  defp wrap_for_structured_content(result) when is_list(result), do: %{items: result}
  defp wrap_for_structured_content(result), do: result
end
