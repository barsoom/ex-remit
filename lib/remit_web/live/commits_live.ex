defmodule RemitWeb.CommitsLive do
  use RemitWeb, :live_view
  alias Remit.Commit

  # Fairly arbitrary number. If too low, we may miss unreviewed stuff. If too high, performance may suffer.
  @commits_count 200

  @impl true
  def mount(_params, session, socket) do
    commits = Commit.load_latest(@commits_count)
    if connected?(socket), do: Commit.subscribe_to_changed_commits()

    socket = socket
      |> assign(email: session["email"], name: session["name"])
      |> assign(your_last_clicked_commit_id: nil)
      |> assign_commits_and_stats(commits)

    {:ok, socket}
  end

  @impl true
  def handle_event("clicked", %{"cid" => commit_id}, socket) do
    socket = assign_clicked_commit_id(socket, commit_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_review", %{"cid" => commit_id}, socket) do
    commit = Commit.mark_as_review_started!(commit_id, socket.assigns.email)

    {:noreply, assign_and_broadcast_changed_commit(socket, commit)}
  end

  @impl true
  def handle_event("mark_reviewed", %{"cid" => commit_id}, socket) do
    commit = Commit.mark_as_reviewed!(commit_id, socket.assigns.email)

    {:noreply, assign_and_broadcast_changed_commit(socket, commit)}
  end

  @impl true
  def handle_event("mark_unreviewed", %{"cid" => commit_id}, socket) do
    commit = Commit.mark_as_unreviewed!(commit_id)

    {:noreply, assign_and_broadcast_changed_commit(socket, commit)}
  end

  # Receive events when other LiveViews update settings.
  @impl true
  def handle_event("set_session", ["name", name], socket) do
    # We need to update the commit stats because they're based on this setting.
    socket = socket
      |> assign(name: name)
      |> assign_commits_and_stats(socket.assigns.commits)

    {:noreply, socket}
  end

  # Receive events when other LiveViews update settings.
  @impl true
  def handle_event("set_session", ["email", email], socket) do
    socket = socket |> assign(email: email)

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

  defp assign_and_broadcast_changed_commit(socket, commit) do
    commits = socket.assigns.commits |> replace_commit(commit)

    Commit.broadcast_changed_commit(commit)

    socket
      |> assign_commits_and_stats(commits)
      |> assign_clicked_commit_id(commit.id)
  end

  defp assign_clicked_commit_id(socket, commit_id) when is_integer(commit_id), do: assign(socket, your_last_clicked_commit_id: commit_id)
  defp assign_clicked_commit_id(socket, commit_id) when is_binary(commit_id), do: assign_clicked_commit_id(socket, String.to_integer(commit_id))

  defp assign_commits_and_stats(socket, commits) do
    unreviewed_count = commits |> Enum.count(& !&1.reviewed_at)
    my_unreviewed_count = commits |> Enum.count(& !&1.reviewed_at && authored?(socket, &1))
    oldest_unreviewed_for_me = commits |> Enum.reverse() |> Enum.find(& !&1.reviewed_at && !authored?(socket, &1))

    assign(socket, %{
      commits: commits,
      unreviewed_count: unreviewed_count,
      my_unreviewed_count: my_unreviewed_count,
      others_unreviewed_count: unreviewed_count - my_unreviewed_count,
      oldest_unreviewed_for_me: oldest_unreviewed_for_me,
    })
  end

  defp replace_commit(commits, commit) do
    commits |> Enum.map(& if(&1.id == commit.id, do: commit, else: &1))
  end

  defp authored?(socket, commit), do: Commit.authored_by?(commit, socket.assigns.name)
end
