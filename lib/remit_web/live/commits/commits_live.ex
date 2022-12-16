defmodule RemitWeb.CommitsLive do
  use RemitWeb, :live_view
  require Logger
  alias Remit.{Commits, Commit, GithubAuth, Ownership, Utils}

  @max_commits Application.compile_env(:remit, :max_commits)
  @overlong_check_frequency_secs 60

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    check_auth_key(session)

    if connected?(socket) do
      Commits.subscribe()
      GithubAuth.subscribe(session["session_id"])
      Ownership.subscribe()
      :timer.send_interval(@overlong_check_frequency_secs * 1000, self(), :check_for_overlong_reviewing)
    end

    socket
    |> assign_defaults(session)
    |> assign_all_teams()
    |> assign_current_commits()
    |> assign_stats()
    |> ok()
  end

  @impl Phoenix.LiveView
  def handle_event("selected", %{"id" => id}, socket) do
    {:noreply, assign_selected_id(socket, id)}
  end

  @impl Phoenix.LiveView
  def handle_event("start_review", %{"id" => id}, socket) do
    commit = Commits.mark_as_review_started!(id, username(socket))
    {:noreply, assign_and_broadcast_changed_commit(socket, commit)}
  end

  @impl Phoenix.LiveView
  def handle_event("mark_reviewed", %{"id" => id}, socket) do
    commit = Commits.mark_as_reviewed!(id, username(socket))
    {:noreply, assign_and_broadcast_changed_commit(socket, commit)}
  end

  @impl Phoenix.LiveView
  def handle_event("mark_unreviewed", %{"id" => id}, socket) do
    commit = Commits.mark_as_unreviewed!(id)
    {:noreply, assign_and_broadcast_changed_commit(socket, commit)}
  end

  @impl Phoenix.LiveView
  def handle_event("set_filter", %{"projects-of-team" => team}, socket) do
    socket
    |> assign(projects_of_team: team)
    |> assign_current_commits()
    |> assign_stats()
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_event("set_filter", %{"members-of-team" => team}, socket) do
    socket
    |> assign(members_of_team: team)
    |> assign_current_commits()
    |> assign_stats()
    |> noreply()
  end

  # Receive broadcasts when other clients update their state.
  @impl Phoenix.LiveView
  def handle_info({:changed_commit, commit}, socket) do
    socket
    |> update_commit(commit)
    |> assign_stats()
    |> noreply()
  end

  # Receive broadcasts when new commits arrive.
  @impl Phoenix.LiveView
  def handle_info({:new_commits, new_commits}, socket) do
    # Check that the new commit satisfies the current filter.
    # Consult the local snapshot state instead of going to the DB so that it doesn't get hit by everyone who is currently connected.

    projects_of_team = projects_of_team(socket)
    members_of_team = members_of_team(socket)
    commit_for_display? = fn commit ->
      Ownership.claimed_by_team_or_unclaimed?(commit.repo, projects_of_team) &&
      Ownership.authors_in_team?(commit.usernames, members_of_team)
    end

    case Enum.filter(new_commits, commit_for_display?) do
      [] ->
        # the new commits are not part of the current filter, skip all updates
        noreply(socket)

      commits ->
        socket
        |> assign_commits(Enum.slice(commits ++ commits(socket), 0, @max_commits))
        |> assign_stats()
        |> noreply()
    end
  end

  def handle_info(:ownership_changed, socket) do
    socket
    |> assign_all_teams()
    |> assign_current_commits()
    |> assign_stats()
    |> noreply()
  end

  # Periodically check.
  @impl Phoenix.LiveView
  def handle_info(:check_for_overlong_reviewing, socket) do
    {:noreply,
     assign(socket,
       oldest_overlong_in_review_by_me: Commit.oldest_overlong_in_review_by(commits(socket), username(socket))
     )}
  end

  @impl Phoenix.LiveView
  def handle_info({:login, %Remit.Github.User{login: login}}, socket) do
    socket
    |> assign(:username, login)
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_info(:logout, socket) do
    socket
    |> assign(:username, nil)
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_info(message, socket) do
    Logger.error("unexpected message #{inspect message}")
    {:noreply, socket}
  end

  # Private

  defp ok(socket), do: {:ok, socket}
  defp noreply(socket), do: {:noreply, socket}

  def assign_defaults(socket, session) do
    socket
    |> assign(username: github_login(session))
    |> assign(your_last_selected_commit_id: nil)
    |> assign(projects_of_team: "all")
    |> assign(members_of_team: "all")
  end

  def assign_all_teams(socket) do
    socket
    |> assign(all_teams: Remit.Team.get_all())
  end

  defp commit_filter(socket) do
    commit_filter_by_projects(projects_of_team(socket)) ++ commit_filter_by_members(members_of_team(socket))
  end

  defp commit_filter_by_projects("all"), do: []
  defp commit_filter_by_projects(team), do: [projects_of_team: team]

  defp commit_filter_by_members("all"), do: []
  defp commit_filter_by_members(team), do: [members_of_team: team]

  def load_commits_for_display(socket) do
    Commits.list_latest(commit_filter(socket), @max_commits)
  end

  def assign_current_commits(socket) do
    socket
    |> assign_commits(load_commits_for_display(socket))
  end

  defp assign_and_broadcast_changed_commit(socket, commit) do
    Commits.broadcast_changed_commit(commit)

    socket
    |> update_commit(commit)
    |> assign_stats()
    |> assign_selected_id(commit.id)
  end

  defp assign_selected_id(socket, id) when is_integer(id), do: assign(socket, your_last_selected_commit_id: id)
  defp assign_selected_id(socket, id) when is_binary(id), do: assign_selected_id(socket, String.to_integer(id))

  defp assign_commits(socket, commits) do
    socket
    |> assign(:commits, Commit.add_date_separators(commits))
  end

  defp update_commit(socket, commit) do
    socket
    |> assign_commits(replace_commit(commits(socket), commit))
  end

  defp assign_stats(socket) do
    commits = commits(socket)

    unreviewed_count = commits |> Enum.count(&(!&1.reviewed_at))
    my_unreviewed_count = commits |> Enum.count(&(!&1.reviewed_at && authored?(socket, &1)))

    assign(socket, %{
      unreviewed_count: unreviewed_count,
      my_unreviewed_count: my_unreviewed_count,
      others_unreviewed_count: unreviewed_count - my_unreviewed_count,
      oldest_unreviewed_for_me: Commit.oldest_unreviewed_for(commits, username(socket)),
      oldest_overlong_in_review_by_me: Commit.oldest_overlong_in_review_by(commits, username(socket))
    })
  end

  defp replace_commit(commits, commit) do
    commits |> Enum.map(&if(&1.id == commit.id, do: commit, else: &1))
  end

  defp authored?(socket, commit), do: Commit.authored_by?(commit, username(socket))

  defp username(socket), do: socket.assigns.username
  defp commits(socket), do: socket.assigns.commits
  defp projects_of_team(socket), do: socket.assigns.projects_of_team
  defp members_of_team(socket), do: socket.assigns.members_of_team
end
