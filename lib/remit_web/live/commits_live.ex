defmodule RemitWeb.CommitsLive do
  use RemitWeb, :live_view
  alias Remit.{Commits, Commit, Utils}

  @max_commits Application.get_env(:remit, :max_commits)
  @overlong_check_frequency_secs 60

  @impl true
  def mount(_params, session, socket) do
    check_auth_key(session)

    if connected?(socket) do
      Commits.subscribe()
      :timer.send_interval(@overlong_check_frequency_secs * 1000, self(), :check_for_overlong_reviewing)
    end

    commits = Commits.list_latest(@max_commits)

    socket =
      socket
      |> assign(username: session["username"])
      |> assign(your_last_selected_commit_id: nil)
      |> assign_commits_and_stats(commits)

    {:ok, socket}
  end

  @impl true
  def handle_event("selected", %{"id" => id}, socket) do
    {:noreply, assign_selected_id(socket, id)}
  end

  @impl true
  def handle_event("start_review", %{"id" => id}, socket) do
    commit = Commits.mark_as_review_started!(id, socket.assigns.username)
    {:noreply, assign_and_broadcast_changed_commit(socket, commit)}
  end

  @impl true
  def handle_event("mark_reviewed", %{"id" => id}, socket) do
    commit = Commits.mark_as_reviewed!(id, socket.assigns.username)
    {:noreply, assign_and_broadcast_changed_commit(socket, commit)}
  end

  @impl true
  def handle_event("mark_unreviewed", %{"id" => id}, socket) do
    commit = Commits.mark_as_unreviewed!(id)
    {:noreply, assign_and_broadcast_changed_commit(socket, commit)}
  end

  # Receive events when other LiveViews update settings.
  @impl true
  def handle_event("set_session", ["username", username], socket) do
    # We need to update the commit stats because they're based on this setting.
    socket =
      socket
      |> assign(username: Utils.normalize_string(username))
      |> assign_commits_and_stats(socket.assigns.commits)

    {:noreply, socket}
  end

  # Receive broadcasts when other clients update their state.
  @impl true
  def handle_info({:changed_commit, commit}, socket) do
    commits = socket.assigns.commits |> replace_commit(commit)
    {:noreply, assign_commits_and_stats(socket, commits)}
  end

  # Receive broadcasts when new commits arrive.
  @impl true
  def handle_info({:new_commits, new_commits}, socket) do
    # Another option here would be to just reload the latest commits from DB.
    commits = Enum.slice(new_commits ++ socket.assigns.commits, 0, @max_commits)
    {:noreply, assign_commits_and_stats(socket, commits)}
  end

  # Periodically check.
  def handle_info(:check_for_overlong_reviewing, socket) do
    {:noreply, assign(socket,
      oldest_overlong_in_review_by_me: Commit.oldest_overlong_in_review_by(socket.assigns.commits, socket.assigns.username)
    )}
  end

  # Private

  defp assign_and_broadcast_changed_commit(socket, commit) do
    commits = socket.assigns.commits |> replace_commit(commit)

    Commits.broadcast_changed_commit(commit)

    socket
    |> assign_commits_and_stats(commits)
    |> assign_selected_id(commit.id)
  end

  defp assign_selected_id(socket, id) when is_integer(id), do: assign(socket, your_last_selected_commit_id: id)
  defp assign_selected_id(socket, id) when is_binary(id), do: assign_selected_id(socket, String.to_integer(id))

  defp assign_commits_and_stats(socket, commits) do
    unreviewed_count = commits |> Enum.count(& !&1.reviewed_at)
    my_unreviewed_count = commits |> Enum.count(& !&1.reviewed_at && authored?(socket, &1))

    commits = Commit.add_date_separators(commits)

    assign(socket, %{
      commits: commits,
      unreviewed_count: unreviewed_count,
      my_unreviewed_count: my_unreviewed_count,
      others_unreviewed_count: unreviewed_count - my_unreviewed_count,
      oldest_unreviewed_for_me: Commit.oldest_unreviewed_for(commits, socket.assigns.username),
      oldest_overlong_in_review_by_me: Commit.oldest_overlong_in_review_by(commits, socket.assigns.username),
    })
  end

  defp replace_commit(commits, commit) do
    commits |> Enum.map(& if(&1.id == commit.id, do: commit, else: &1))
  end

  defp authored?(socket, commit), do: Commit.authored_by?(commit, socket.assigns.username)
end
