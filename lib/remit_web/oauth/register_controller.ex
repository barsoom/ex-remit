defmodule RemitWeb.OAuth.RegisterController do
  @moduledoc """
  RFC 7591 Dynamic Client Registration. Stateless: returns a synthetic
  random `client_id`, persists nothing. Trust comes from the loopback
  redirect-URI allowlist + PKCE — the client_id is diagnostic only.
  """
  use RemitWeb, :controller

  def register(conn, params) do
    client_id = "remit-dcr-" <> (:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false))

    response =
      Map.merge(params, %{
        "client_id" => client_id,
        "client_id_issued_at" => System.system_time(:second),
        "token_endpoint_auth_method" => "none"
      })

    conn
    |> put_status(201)
    |> json(response)
  end
end
