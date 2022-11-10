defmodule RemitWeb.SettingsLive do
  use RemitWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    check_auth_key(session)

    {:ok, assign(socket, username: github_login(session))}
  end
end
