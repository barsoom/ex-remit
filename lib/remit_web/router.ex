defmodule RemitWeb.Router do
  use RemitWeb, :router
  use Honeybadger.Plug
  import RemitWeb.Auth.Routing
  import RemitWeb.Auth.Controller, only: [authenticate_bearer: 2, validate_origin: 2, validate_protocol_version: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :ensure_session_id
    plug :fetch_live_flash
    plug :put_root_layout, html: {RemitWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :check_auth_key
  end

  scope "/", RemitWeb do
    get "/revision", RootController, :revision
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
    post "/update_github_teams", TeamsController, :update
    post "/logout", GithubAuthController, :logout
    post "/filter_preference/:scope", UserController, :set_filter_preference
    post "/reviewed_commit_cutoff", UserController, :set_reviewed_commit_cutoff
    post "/features", UserController, :set_feature_flag
  end

  pipeline :webhook do
    plug :accepts, ["json"]
    plug :check_webhook_key
  end

  scope "/webhooks", RemitWeb do
    pipe_through :webhook

    post "/github", GithubWebhookController, :create
  end

  # OAuth surface — deliberately bypasses :check_auth_key.

  pipeline :oauth_browser do
    plug :accepts, ["html", "json"]
    plug :fetch_session
    plug :ensure_session_id
    plug :fetch_live_flash
    plug :put_root_layout, html: {RemitWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :oauth_public do
    plug :accepts, ["json"]
  end

  scope "/.well-known", RemitWeb.OAuth do
    pipe_through :oauth_public

    get "/oauth-authorization-server", AuthServerController, :show
    get "/oauth-protected-resource/mcp", ProtectedResourceController, :show
  end

  scope "/oauth", RemitWeb.OAuth do
    pipe_through :oauth_browser

    get "/authorize", AuthorizeController, :authorize
  end

  scope "/oauth", RemitWeb.OAuth do
    pipe_through :oauth_public

    post "/token", TokenController, :token
    post "/register", RegisterController, :register
  end

  # MCP and CLI surfaces — bearer-authed.

  pipeline :mcp do
    plug :accepts, ["json"]
    plug :validate_origin
    plug :validate_protocol_version
    plug :authenticate_bearer
  end

  scope "/", RemitWeb do
    pipe_through :mcp

    post "/mcp", MCPController, :handle
    get "/mcp", MCPController, :stream
  end

  pipeline :cli_api do
    plug :accepts, ["json"]
    plug :authenticate_bearer
  end

  scope "/api/cli", RemitWeb.CLI do
    pipe_through :cli_api

    get "/whoami", AuthController, :whoami
    get "/stats", ToolController, :stats
    get "/commits", ToolController, :list_commits
    get "/comments", ToolController, :list_comments
    get "/teams", ToolController, :list_teams
    post "/commits/:id/review", ToolController, :mark_reviewed
    post "/commits/:id/unreview", ToolController, :mark_unreviewed
    post "/commits/:id/start_review", ToolController, :start_review
    post "/comments/:id/resolve", ToolController, :resolve_comment
    post "/comments/:id/unresolve", ToolController, :unresolve_comment
  end
end
