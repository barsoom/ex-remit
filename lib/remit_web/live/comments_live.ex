defmodule RemitWeb.CommentsLive do
  use RemitWeb, :live_view
  alias Remit.{Repo, Comment}

  @max_comments Application.get_env(:remit, :max_comments)

  @impl true
  def mount(_params, session, socket) do
    check_auth_key(session)
    if connected?(socket), do: Comment.subscribe()

    comments =
      Comment.load_latest(@max_comments)
      |> Repo.preload(:commit)

    socket = assign(socket, comments: comments)

    {:ok, socket}
  end

  # Receive broadcasts when new comments arrive.
  @impl true
  def handle_info({:new_comment, new_comment}, socket) do
    comments = [new_comment | socket.assigns.comments] |> Enum.slice(0, @max_comments)
    socket = assign(socket, comments: comments)

    {:noreply, socket}
  end
end
