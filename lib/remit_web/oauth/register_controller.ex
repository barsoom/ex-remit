defmodule RemitWeb.OAuth.RegisterController do
  @moduledoc """
  RFC 7591 Dynamic Client Registration. Stateless: returns a synthetic
  random `client_id`, persists nothing. Trust comes from the loopback
  redirect-URI allowlist + PKCE; the client_id is diagnostic only.
  """
  use RemitWeb, :controller
  alias RemitWeb.OAuth.ClientPolicy

  def register(conn, %{"redirect_uris" => [_ | _] = redirect_uris} = params) do
    if Enum.all?(redirect_uris, &(ClientPolicy.validate_redirect_uri(&1) == :ok)) do
      client_id = "remit-dcr-" <> (:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false))

      response =
        params
        |> Map.take(~w(client_name redirect_uris))
        |> Map.merge(%{
          "client_id" => client_id,
          "client_id_issued_at" => System.system_time(:second),
          "token_endpoint_auth_method" => "none"
        })

      conn
      |> put_status(201)
      |> json(response)
    else
      invalid_redirect_uri(conn)
    end
  end

  def register(conn, _params), do: invalid_redirect_uri(conn)

  defp invalid_redirect_uri(conn) do
    conn
    |> put_status(400)
    |> json(%{
      "error" => "invalid_redirect_uri",
      "error_description" => "redirect_uris must be loopback URIs ending in /callback"
    })
  end
end
