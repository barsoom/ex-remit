defmodule RemitWeb.CommentsLive do
  use RemitWeb, :live_view
  alias Remit.{Comments, Utils}

  @max_comments Application.get_env(:remit, :max_comments)

  @impl true
  def mount(_params, session, socket) do
    check_auth_key(session)

    if connected?(socket) do
      send(socket.parent_pid, {:comments_pid, self()})
      Comments.subscribe()
    end

    username = session["username"]

    socket =
      socket
      |> assign(your_last_selected_id: nil)
      |> assign(username: username)
      |> assign_params(session)  # Sic. From parent; can't use `_params` since we're not mounted at root.
      |> assign_filtered_notifications()

    {:ok, socket}
  end

  @impl true
  def handle_event("selected", %{"id" => id}, socket) do
    {:noreply, assign_selected_id(socket, id)}
  end

  @impl true
  def handle_event("resolve", %{"id" => id}, socket) do
    Comments.resolve(id)
    socket = assign_selected_id(socket, id)
    socket = assign_filtered_notifications(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("unresolve", %{"id" => id}, socket) do
    Comments.unresolve(id)
    socket = assign_selected_id(socket, id)
    socket = assign_filtered_notifications(socket)

    {:noreply, socket}
  end

  # Receive events when other LiveViews update settings.
  @impl true
  def handle_event("set_session", ["username", username], socket) do
    socket =
      socket
      |> assign(username: Utils.normalize_string(username))
      |> assign_filtered_notifications()

    {:noreply, socket}
  end
  def handle_event("set_session", _, socket), do: {:noreply, socket}

  # Receive broadcasts when new comments arrive or have their state changed by another user.
  @impl true
  def handle_info(:comments_changed, socket) do
    # We just re-load from DB; filtering in memory could get fiddly if we need to hang on to both a filtered and an unfiltered list.
    socket = assign_filtered_notifications(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_params, params}, socket) do
    socket = assign_params(socket, params)
    socket = assign_filtered_notifications(socket)
    {:noreply, socket}
  end

  # Private

  defp assign_params(socket, params) do
    assign(socket,
      is: params["is"] || "unresolved",
      role: params["role"] || (if socket.assigns.username, do: "for_me", else: "all")
    )
  end

  defp assign_selected_id(socket, id) when is_integer(id), do: assign(socket, your_last_selected_id: id)
  defp assign_selected_id(socket, id) when is_binary(id), do: assign_selected_id(socket, String.to_integer(id))

  defp assign_filtered_notifications(socket) do
    notifications = Comments.list_notifications(
      limit: @max_comments,
      username: socket.assigns.username,
      resolved_filter: socket.assigns.is,
      user_filter: socket.assigns.role
    )

    assign(socket, notifications: notifications)
  end

  defp filter_link(socket, assigns, text, is: is) do
    live_patch text, to: Routes.tabs_path(socket, :comments, is: is, role: assigns.role), class: (if is == assigns.is, do: "font-bold no-underline")
  end
  defp filter_link(socket, assigns, text, role: role) do
    live_patch text, to: Routes.tabs_path(socket, :comments, is: assigns.is, role: role), class: (if role == assigns.role, do: "font-bold no-underline")
  end
end
