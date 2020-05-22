defmodule RemitWeb.Router do
  use RemitWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {RemitWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
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
end
