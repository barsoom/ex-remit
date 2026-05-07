defmodule RemitWeb.OAuth.ProtectedResourceController do
  @moduledoc """
  RFC 9728 Protected Resource metadata for `/mcp`.
  """
  use RemitWeb, :controller

  def show(conn, _params) do
    base = RemitWeb.OAuth.BaseURL.from_conn(conn)

    json(conn, %{
      "resource" => base <> "/mcp",
      "authorization_servers" => [base],
      "bearer_methods_supported" => ["header"],
      "scopes_supported" => RemitWeb.OAuth.ClientPolicy.scope_ceiling()
    })
  end
end
