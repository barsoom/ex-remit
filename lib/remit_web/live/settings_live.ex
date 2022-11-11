defmodule RemitWeb.SettingsLive do
  use RemitWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    check_auth_key(session)

    {:ok, assign(socket, username: github_login(session))}
  end

  @impl Phoenix.LiveView
  def handle_event("logout", _, socket) do
    socket
    |> assign(:username, nil)
    |> noreply()
  end

  defp noreply(socket), do: {:noreply, socket}
end
