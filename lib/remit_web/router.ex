defmodule RemitWeb.Router do
  use RemitWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {RemitWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :check_auth_key
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :check_auth_key
  end

  scope "/", RemitWeb do
    pipe_through :browser

    live "/", TabsLive, :commits
    live "/comments", TabsLive, :comments
    live "/settings", TabsLive, :settings
  end

  scope "/api", RemitWeb do
    pipe_through :api

    post "/session", SessionController, :set
  end

  @expected_auth_key Application.get_env(:remit, :auth_key)

  # Also see `RemitWeb.LiveHelpers.check_auth_key/1`.
  defp check_auth_key(conn, _opts) do
    given_auth_key = conn.params["auth_key"] || get_session(conn, :auth_key)

    # Keep it in session so we stay authed without having to pass it around, and so LiveViews can access it on mount.
    conn = conn |> put_session(:auth_key, given_auth_key)

    if given_auth_key == @expected_auth_key do
      conn
    else
      conn |> deny_access_with("Invalid auth_key")
    end
  end

  defp deny_access_with(conn, text), do: conn |> send_resp(403, text) |> halt()
end
