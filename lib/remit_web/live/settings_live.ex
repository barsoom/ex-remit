defmodule RemitWeb.SettingsLive do
  use RemitWeb, :live_view
  require Logger
  alias Remit.GithubAuth

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    check_auth_key(session)

    if connected?(socket) do
      GithubAuth.subscribe(session["session_id"])
    end

    {:ok, assign(socket, username: github_login(session))}
  end

  @impl Phoenix.LiveView
  def handle_info({:login, %Remit.Github.User{login: login}}, socket) do
    socket
    |> assign(:username, login)
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_info(:logout, socket) do
    socket
    |> assign(:username, nil)
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_info(message, socket) do
    Logger.error("unexpected message #{inspect message}")
    {:noreply, socket}
  end

  defp noreply(socket), do: {:noreply, socket}
end
