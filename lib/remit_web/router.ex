defmodule RemitWeb.Router do
  use RemitWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {RemitWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :assign_session_id
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RemitWeb do
    pipe_through :browser

    live "/", TabsLive, :commits
    live "/comments", TabsLive, :comments
    live "/settings", TabsLive, :settings
  end

  defp assign_session_id(conn, _) do
    if get_session(conn, :session_id) do
      conn
    else
      put_session(conn, :session_id, Ecto.UUID.generate())
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", RemitWeb do
  #   pipe_through :api
  # end
end
