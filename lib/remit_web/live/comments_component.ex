defmodule RemitWeb.CommentsComponent do
  use RemitWeb, :live_component
  alias Remit.{Comments, Utils}

  @max_comments Application.get_env(:remit, :max_comments)
  @default_params %{"resolved" => "unresolved", "user" => "for_me"}

  @impl true
  def mount(socket) do
    if connected?(socket), do: Comments.subscribe()

    socket = assign(socket, your_last_selected_id: nil)

    {:ok, socket}
  end

  @impl true
  def update(parent_assigns, socket) do
    socket = assign(socket,
        username: parent_assigns.username,
        params: Map.merge(@default_params, parent_assigns.params)
      )

    socket = assign_filtered_notifications(socket)

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

  # Private

  defp assign_selected_id(socket, id) when is_integer(id), do: assign(socket, your_last_selected_id: id)
  defp assign_selected_id(socket, id) when is_binary(id), do: assign_selected_id(socket, String.to_integer(id))

  defp assign_filtered_notifications(socket) do
    notifications = Comments.list_notifications(
      limit: @max_comments,
      username: socket.assigns.username,
      resolved_filter: socket.assigns.params["resolved"],
      user_filter: socket.assigns.params["user"]
    )

    assign(socket, notifications: notifications)
  end

  defp filter_link(socket, text, params, changes) do
    current? = MapSet.subset?(MapSet.new(changes), MapSet.new(params))

    live_patch text,
      to: Routes.tabs_path(socket, :comments, Map.merge(params, changes)),
      class: (if current?, do: "font-bold no-underline")
  end
end
