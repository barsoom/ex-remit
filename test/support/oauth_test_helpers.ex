defmodule RemitWeb.OAuthTestHelpers do
  @moduledoc """
  Test helpers for issuing JWT bearer tokens with arbitrary scope.
  """
  alias RemitWeb.OAuth.JWT

  @default_login "octocat"

  def bearer(conn, scopes \\ ["remit:read", "remit:review"], login \\ @default_login) do
    {:ok, token} = JWT.sign_access(%{"sub" => login, "scope" => Enum.join(scopes, " ")})
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end
end
