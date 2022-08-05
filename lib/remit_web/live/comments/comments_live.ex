defmodule RemitWeb.CommentsLive do
  use RemitWeb, :live_view
  alias Remit.{Comments, Utils}

  @max_comments Application.get_env(:remit, :max_comments)

  @impl true
  def mount(_params, session, socket) do
    check_auth_key(session)

    if connected?(socket) do
      Comments.subscribe()
    end

    username = session["username"]

    socket =
      socket
      |> assign(your_last_selected_id: nil)
      |> assign(username: username)
      |> assign_default_params()
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

  def handle_event("set_filter", %{"is" => is}, socket) do
    socket = socket
             |> assign(is: is)
             |> assign_filtered_notifications()
    {:noreply, socket}
  end

  def handle_event("set_filter", %{"role" => role}, socket) do
    socket = socket
             |> assign(role: role)
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

  defp assign_default_params(socket) do
    assign(socket,
      is: "unresolved",
      role: if(socket.assigns.username, do: "for_me", else: "all")
    )
  end

  defp assign_selected_id(socket, id) when is_integer(id), do: assign(socket, your_last_selected_id: id)
  defp assign_selected_id(socket, id) when is_binary(id), do: assign_selected_id(socket, String.to_integer(id))

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

  defp filter_link(socket, assigns, text, [{param, value}]) do
    link text, to: Routes.tabs_path(socket, :comments),
               class: link_classes(value, assigns[param]),
               "phx-click": "set_filter",
               "phx-value-#{param}": value,
               "phx-hook": "CancelDefaultNavigation"
  end

  defp link_classes(link_attr, current_attr) do
    if link_attr == current_attr do
      ~w(cursor-default no-underline font-bold)
    else
      ~w(cursor-pointer underline)
    end
  end
end
