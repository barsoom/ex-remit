defmodule RemitWeb.Router do
  use RemitWeb, :router
  use Honeybadger.Plug
  import RemitWeb.Auth.Routing

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :ensure_session_id
    plug :fetch_live_flash
    plug :put_root_layout, {RemitWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :check_auth_key
  end

  scope "/", RemitWeb do
    import Phoenix.LiveDashboard.Router
    pipe_through :browser

    get "/", Redirect, to: "/commits"
    live "/commits", TabsLive, :commits
    live "/comments", TabsLive, :comments
    live "/settings", TabsLive, :settings

    get "/login", GithubAuthController, :login
    get "/auth", GithubAuthController, :auth

    live_dashboard "/dashboard", metrics: RemitWeb.Telemetry
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :ensure_session_id
    plug :check_auth_key
  end

  scope "/api", RemitWeb do
    pipe_through :api

    get "/stats", StatsController, :show
    post "/logout", GithubAuthController, :logout
  end

  pipeline :webhook do
    plug :accepts, ["json"]
    plug :check_webhook_key
  end

  scope "/webhooks", RemitWeb do
    pipe_through :webhook

    post "/github", GithubWebhookController, :create
  end
end
