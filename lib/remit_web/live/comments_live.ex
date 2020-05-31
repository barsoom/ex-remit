defmodule RemitWeb.CommentsLive do
  use RemitWeb, :live_view
  alias Remit.{Comments, Utils}

  @max_comments Application.get_env(:remit, :max_comments)

  @impl true
  def mount(_params, session, socket) do
    check_auth_key(session)
    if connected?(socket), do: Comments.subscribe()

    socket =
      socket
      |> assign(
        username: session["username"],
        resolved_state: "unresolved",
        direction: "for_me"
      )
      |> assign_filtered_notifications()

    {:ok, socket}
  end

  @impl true
  def handle_event("change_resolved_state", %{"filter" => state}, socket) do
    socket =
      socket
      |> assign(resolved_state: state)
      |> assign_filtered_notifications()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_direction", %{"filter" => direction}, socket) do
    socket =
      socket
      |> assign(direction: direction)
      |> assign_filtered_notifications()

    {:noreply, socket}
  end

  @impl true
  def handle_event("resolve", %{"nid" => id}, socket) do
    Comments.resolve(id)
    socket = assign_filtered_notifications(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("unresolve", %{"nid" => id}, socket) do
    Comments.unresolve(id)
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

  # Private

  defp assign_filtered_notifications(socket) do
    notifications = Comments.list_notifications(
      limit: @max_comments,
      username: socket.assigns.username,
      resolved_filter: socket.assigns.resolved_state,
      user_filter: socket.assigns.direction
    )

    assign(socket, notifications: notifications)
  end

  defp filter_link(text, event, value, current_value) do
    Phoenix.HTML.Tag.content_tag(:a, text, href: "#", "phx-click": event, "phx-value-filter": value, class: (if current_value == value, do: "font-bold no-underline"))
  end
end
