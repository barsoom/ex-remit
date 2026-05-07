defmodule RemitWeb.MCPController do
  @moduledoc """
  HTTP shell for the JSON-RPC `/mcp` surface. Top-level JSON arrays
  (batch requests) arrive as the `_json` param.
  """
  use RemitWeb, :controller
  alias RemitWeb.MCP.Server

  def handle(conn, %{"_json" => batch}) when is_list(batch) do
    responses =
      Enum.flat_map(batch, fn req ->
        case Server.handle(req, conn) do
          :no_response -> []
          response -> [response]
        end
      end)

    if responses == [] do
      send_resp(conn, 202, "")
    else
      json(conn, responses)
    end
  end

  def handle(conn, params) do
    case Server.handle(params, conn) do
      :no_response -> send_resp(conn, 202, "")
      response -> json(conn, response)
    end
  end

  def stream(conn, _params), do: send_resp(conn, 405, "")
end
