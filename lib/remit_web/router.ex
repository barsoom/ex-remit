defmodule RemitWeb.Router do
  use RemitWeb, :router
  import RemitWeb.Auth.Routing

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {RemitWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :check_auth_key
  end

  scope "/", RemitWeb do
    pipe_through :browser

    get "/", Redirect, to: "/commits"
    live "/commits", TabsLive, :commits
    live "/comments", TabsLive, :comments
    live "/settings", TabsLive, :settings
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :check_auth_key
  end

  scope "/api", RemitWeb do
    pipe_through :api

    post "/session", SessionController, :set
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
