defmodule RemitWeb.CommitsLive do
  use RemitWeb, :live_view
  alias Remit.{Repo,Commit,Settings}

  # Fairly arbitrary number. If too low, we may miss unreviewed stuff. If too high, performance may suffer.
  @commits_count 200

  # We subscribe on mount, and then when one client updates state, it broadcasts the new state to other clients.
  # Read more: https://elixirschool.com/blog/live-view-with-pub-sub/
  @broadcast_topic "commits"

  @impl true
  def mount(_params, session, socket) do
    Phoenix.PubSub.subscribe(Remit.PubSub, @broadcast_topic)

    settings = Settings.for_session(session)
    commits = Commit.load_latest(@commits_count)

    # We previously used temporary assigns (https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-dom-patching-and-temporary-assigns) for `commits` to avoid sending a lot of data over the wire when a single commit is updated (e.g. reviewed), but it had the downside of not having the full list of commits available to run logic on.
    #
    # So instead, we keep the full list of commits in memory, but render each commit via a stateful component, which has the effect of not re-sending all the commits each time a single commit is changed.
    socket = socket
      |> assign(page_title: "Commits", settings: settings)
      |> assign_commits_and_stats(commits)

    {:ok, socket}
  end

  @impl true
  def handle_event("mark_reviewed", %{"cid" => commit_id}, socket) do
    commit = Commit.mark_as_reviewed!(commit_id) |> preload() |> broadcast_changed_commit()

    commits = socket.assigns.commits |> replace_commit(commit)
    socket = socket |> assign_commits_and_stats(commits)

    {:noreply, socket}
  end

  @impl true
  def handle_event("mark_unreviewed", %{"cid" => commit_id}, socket) do
    commit = Commit.mark_as_unreviewed!(commit_id) |> preload() |> broadcast_changed_commit()

    commits = socket.assigns.commits |> replace_commit(commit)
    socket = socket |> assign_commits_and_stats(commits)

    {:noreply, socket}
  end

  # Receive broadcasts when other clients update their state.
  @impl true
  def handle_info({:changed_commit, commit}, socket) do
    commits = socket.assigns.commits |> replace_commit(commit)
    socket = socket |> assign_commits_and_stats(commits)

    {:noreply, socket}
  end

  # Private

  defp assign_commits_and_stats(socket, commits) do
    unreviewed_count = commits |> Enum.count(& !&1.reviewed_at)
    my_unreviewed_count = commits |> Enum.count(& !&1.reviewed_at && Settings.authored?(socket.assigns.settings, &1))

    assign(socket, %{
      commits: commits,
      unreviewed_count: unreviewed_count,
      my_unreviewed_count: my_unreviewed_count,
      others_unreviewed_count: unreviewed_count - my_unreviewed_count,
    })
  end

  defp replace_commit(commits, commit) do
    commits |> Enum.map(& if(&1.id == commit.id, do: commit, else: &1))
  end

  defp preload(%Commit{} = commit), do: commit |> Repo.preload(:author)

  defp broadcast_changed_commit(commit) do
    Phoenix.PubSub.broadcast_from(Remit.PubSub, self(), @broadcast_topic, {:changed_commit, commit})
    commit
  end
end
