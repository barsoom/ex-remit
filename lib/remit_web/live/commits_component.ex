defmodule RemitWeb.CommitsComponent do
  use RemitWeb, :live_component
  alias Remit.{Commits, Commit, Utils}

  @max_commits Application.get_env(:remit, :max_commits)

  @impl true
  def mount(socket) do
    socket = assign(socket,
      your_last_selected_commit_id: nil,
      commits: Commits.list_latest(@max_commits)
    )

    {:ok, socket}
  end

  # Updates

  @impl true
  def update(%{username: username}, socket) do
    socket =
      socket
      |> assign(username: username)
      |> assign_commits_and_stats(socket.assigns.commits)

    {:ok, socket}
  end

  @impl true
  def update(%{check_for_overlong_reviewing: true}, socket) do
    {:ok, assign(socket,
      oldest_overlong_in_review_by_me: Commit.oldest_overlong_in_review_by(socket.assigns.commits, socket.assigns.username)
    )}
  end

  @impl true
  def update(%{changed_commit: commit}, socket) do
    commits = socket.assigns.commits |> replace_commit(commit)
    {:ok, assign_commits_and_stats(socket, commits)}
  end

  @impl true
  def update(%{new_commits: new_commits}, socket) do
    commits = Enum.slice(new_commits ++ socket.assigns.commits, 0, @max_commits)
    {:ok, assign_commits_and_stats(socket, commits)}
  end

  # Events

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
