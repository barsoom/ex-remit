defmodule RemitWeb.CommentsLive do
  use RemitWeb, :live_view
  alias Remit.{Repo, Comment}

  # Fairly arbitrary number. If too low, we may miss stuff. If too high, performance may suffer.
  @comments_count 200

  @impl true
  def mount(_params, session, socket) do
    check_auth_key(session)

    comments =
      Comment.load_latest(@comments_count)
      |> Repo.preload(:commit)

    socket =
      socket
      |> assign(comments: comments)

    {:ok, socket}
  end
end
