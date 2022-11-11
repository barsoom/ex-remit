defmodule RemitWeb.CommentsLive do
  use RemitWeb, :live_view
  require Logger
  alias Remit.{Comments, GithubAuth}

  @max_comments Application.compile_env(:remit, :max_comments)

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    check_auth_key(session)

    if connected?(socket) do
      Comments.subscribe()
      GithubAuth.subscribe(session["session_id"])
    end

    socket
    |> assign(your_last_selected_id: nil)
    |> assign_username(github_login(session))
    |> assign_default_params()
    |> assign_filtered_notifications()
    |> ok()
  end

  @impl Phoenix.LiveView
  def handle_event("selected", %{"id" => id}, socket) do
    {:noreply, assign_selected_id(socket, id)}
  end

  @impl Phoenix.LiveView
  def handle_event("resolve", %{"id" => id}, socket) do
    Comments.resolve(id)
    socket
    |> assign_selected_id(id)
    |> assign_filtered_notifications()
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_event("unresolve", %{"id" => id}, socket) do
    Comments.unresolve(id)
    socket
    |> assign_selected_id(id)
    |> assign_filtered_notifications()
    |> noreply()
  end

  def handle_event("set_filter", %{"is" => is}, socket) do
    socket
    |> assign(is: is)
    |> assign_filtered_notifications()
    |> noreply()
  end

  def handle_event("set_filter", %{"role" => role}, socket) do
    socket
    |> assign(role: role)
    |> assign_filtered_notifications()
    |> noreply()
  end

  # Receive broadcasts when new comments arrive or have their state changed by another user.
  @impl Phoenix.LiveView
  def handle_info(:comments_changed, socket) do
    # We just re-load from DB; filtering in memory could get fiddly if we need to hang on to both a filtered and an unfiltered list.
    socket = assign_filtered_notifications(socket)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:login, %Remit.Github.User{login: login}}, socket) do
    socket
    |> assign_username_and_update_filter(login)
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_info(:logout, socket) do
    socket
    |> assign_username_and_update_filter(nil)
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_info(message, socket) do
    Logger.error("unexpected message #{inspect message}")
    {:noreply, socket}
  end

  # Private

  defp ok(socket), do: {:ok, socket}
  defp noreply(socket), do: {:noreply, socket}

  defp assign_default_params(socket) do
    assign(socket,
      is: "unresolved",
      role: if(socket.assigns.username, do: "for_me", else: "all")
    )
  end

  defp assign_selected_id(socket, id) when is_integer(id), do: assign(socket, your_last_selected_id: id)
  defp assign_selected_id(socket, id) when is_binary(id), do: assign_selected_id(socket, String.to_integer(id))

  # most of the time these should get updated together
  defp assign_username_and_update_filter(socket, username) do
    socket
    |> assign_username(username)
    |> assign_filtered_notifications()
  end

  defp assign_username(socket, username) do
    socket
    |> assign(username: username)
  end

  defp assign_filtered_notifications(socket) do
    notifications =
      Comments.list_notifications(
        limit: @max_comments,
        username: socket.assigns.username,
        resolved_filter: socket.assigns.is,
        user_filter: socket.assigns.role
      )

    assign(socket, notifications: notifications)
  end
end
