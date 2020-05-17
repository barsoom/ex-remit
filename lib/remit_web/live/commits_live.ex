defmodule RemitWeb.CommitsLive do
  use RemitWeb, :live_view
  alias Remit.{Repo,Commit}

  # Fairly arbitrary number. If too low, we may miss unreviewed stuff. If too high, performance may suffer.
  @commits_count 200

  # We subscribe on mount, and then when one client updates state, it broadcasts the new state to other clients.
  # Read more: https://elixirschool.com/blog/live-view-with-pub-sub/
  @broadcast_topic "commits"

  @impl true
  def mount(_params, session, socket) do
    Phoenix.PubSub.subscribe(Remit.PubSub, @broadcast_topic)

    commits = Commit.load_latest(@commits_count)

    socket = assign(socket, %{
      page_title: "Commits",
      commits: commits,
      unreviewed_count: commits |> Enum.count(& !&1.reviewed_at)
    })

    # Flag `commits` as a "temporary assign" defaulting to `[]`.
    # This means we don't have to keep the full list of commits in memory: we just assign new or updated ones, and LiveView knows to replace or append/prepend them.
    # https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-dom-patching-and-temporary-assigns
    {:ok, socket, temporary_assigns: [commits: []]}
  end

  @impl true
  def handle_event("mark_reviewed", %{"cid" => commit_id}, socket) do
    IO.inspect {socket, socket}
    commit = Commit.mark_as_reviewed!(commit_id) |> Repo.preload(:author)

    new_assigns = %{ commits: [commit], unreviewed_count: (socket.assigns.unreviewed_count - 1) }  # Only assign the new commit: see above about "temporary assigns".
    broadcast(new_assigns)

    IO.inspect socket

    {:noreply, assign(socket, new_assigns)}
  end

  @impl true
  def handle_event("mark_unreviewed", %{"cid" => commit_id}, socket) do
    commit = Commit.mark_as_unreviewed!(commit_id) |> Repo.preload(:author)

    new_assigns = %{ commits: [commit], unreviewed_count: (socket.assigns.unreviewed_count + 1) }  # Only assign the new commit: see above about "temporary assigns".
    broadcast(new_assigns)

    {:noreply, assign(socket, new_assigns)}
  end

  # Receive broadcasts when other clients update their state.
  @impl true
  def handle_info({:set_assigns, new_assigns}, socket) do
    {:noreply, assign(socket, new_assigns)}
  end

  defp broadcast(assigns) do
    Phoenix.PubSub.broadcast_from(Remit.PubSub, self(), @broadcast_topic, {:set_assigns, assigns})
  end
end
