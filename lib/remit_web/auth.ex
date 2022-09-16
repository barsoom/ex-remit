defmodule RemitWeb.Auth do
  @moduledoc false
  defmodule Routing do
    @moduledoc false
    import Plug.Conn

    def check_auth_key(conn, _opts) do
      given_key = conn.params["auth_key"] || get_session(conn, :auth_key)

      # Keep it in session so we stay authed without having to pass it around, and so LiveViews can access it on mount.
      conn = conn |> put_session(:auth_key, given_key)

      check_key(conn, given_key, Remit.Config.auth_key())
    end

    def check_webhook_key(conn, _opts) do
      given_key = conn.params["auth_key"]
      check_key(conn, given_key, Remit.Config.webhook_key())
    end

    # Private

    defp check_key(conn, given_key, expected_key) do
      if given_key == expected_key do
        conn
      else
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(403, "Invalid auth_key")
        |> halt()
      end
    end
  end

  # Based on https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-security-considerations-of-the-liveview-model.
  defmodule LiveView do
    @moduledoc false
    def check_auth_key(session) do
      given_auth_key = session["auth_key"]
      if given_auth_key != Remit.Config.auth_key(), do: throw("Invalid auth_key in LiveView: #{given_auth_key}")
    end
  end

  defmodule Socket do
    @moduledoc false
    def authed_via_socket_params?(%{"auth_key" => given_auth_key}) do
      given_auth_key == Remit.Config.auth_key()
    end
  end
end
