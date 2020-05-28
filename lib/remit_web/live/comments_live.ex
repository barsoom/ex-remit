defmodule RemitWeb.CommentsLive do
  use RemitWeb, :live_view
  alias Remit.{Repo, Comment}

  # Fairly arbitrary number. If too low, we may miss stuff. If too high, performance may suffer.
  @comments_count 200

  @impl true
  def mount(_params, session, socket) do
    check_auth_key(session)
    if connected?(socket), do: Comment.subscribe()

    comments =
      Comment.load_latest(@comments_count)
      |> Repo.preload(:commit)

    socket = assign(socket, comments: comments)

    {:ok, socket}
  end

  # Receive broadcasts when new comments arrive.
  @impl true
  def handle_info({:new_comment, new_comment}, socket) do
    comments = [new_comment | socket.assigns.comments] |> Enum.slice(0, @comments_count)
    socket = assign(socket, comments: comments)

    {:noreply, socket}
  end
end
