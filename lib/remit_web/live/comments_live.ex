defmodule RemitWeb.CommentsLive do
  use RemitWeb, :live_view
  import Ecto.Query
  alias Remit.{Repo, Comment, CommentNotification, Utils}

  @max_comments Application.get_env(:remit, :max_comments)

  @impl true
  def mount(_params, session, socket) do
    check_auth_key(session)
    if connected?(socket), do: Comment.subscribe()

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
  def handle_event("change_resolved_state", %{"state" => state}, socket) do
    socket =
      socket
      |> assign(resolved_state: state)
      |> assign_filtered_notifications()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_direction", %{"direction" => direction}, socket) do
    socket =
      socket
      |> assign(direction: direction)
      |> assign_filtered_notifications()

    {:noreply, socket}
  end

  @impl true
  def handle_event("resolve", %{"nid" => id}, socket) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Repo.get_by(CommentNotification, id: id)
    |> Ecto.Changeset.change(resolved_at: now)
    |> Repo.update!()

    socket = assign_filtered_notifications(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("unresolve", %{"nid" => id}, socket) do
    Repo.get_by(CommentNotification, id: id)
    |> Ecto.Changeset.change(resolved_at: nil)
    |> Repo.update!()

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

  # Receive broadcasts when new comments arrive.
  @impl true
  # TODO: Remove comment from payload, or change to notification and use that?
  def handle_info({:new_comment, _new_comment}, socket) do
    socket = assign_filtered_notifications(socket)

    {:noreply, socket}
  end

  # Private

  defp assign_filtered_notifications(socket) do
    username = socket.assigns.username

    query = from n in CommentNotification,
      limit: @max_comments,
      join: c in assoc(n, :comment),
      preload: [comment: {c, [:commit]}],
      order_by: [desc: :id]

    query =
      case socket.assigns.resolved_state do
        "unresolved" -> from n in query, where: is_nil(n.resolved_at), order_by: [asc: :id]
        "resolved" -> from n in query, where: not is_nil(n.resolved_at), order_by: [desc: :resolved_at]
        "all" -> from query, order_by: [desc: :id]
      end

    query =
      case {username, socket.assigns.direction} do
        {nil, _} -> query
        {_, "all"} -> query
        {_, "for_me"} -> from n in query, where: n.username == ^username
        {_, "by_me"} -> from [n, c] in query, where: c.commenter_username == ^username
      end

    notifications = Repo.all(query)

    assign(socket, notifications: notifications)
  end
end
