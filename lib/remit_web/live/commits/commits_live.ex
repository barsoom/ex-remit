defmodule RemitWeb.CommitsLive do
  use RemitWeb, :live_view
  require Logger
  alias Remit.{Commits, Commit, GithubAuth, Utils}

  @max_commits Application.compile_env(:remit, :max_commits)
  @overlong_check_frequency_secs 60

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    check_auth_key(session)

    if connected?(socket) do
      Commits.subscribe()
      GithubAuth.subscribe(session["session_id"])
      :timer.send_interval(@overlong_check_frequency_secs * 1000, self(), :check_for_overlong_reviewing)
    end

    commits = Commits.list_latest(@max_commits)

    socket
    |> assign_defaults(session)
    |> assign_commits_and_stats(commits)
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
  def handle_event("set_filter", %{"team" => team}, socket) do
    socket
    |> assign(team: team)
    |> assign_filtered_projects()
    |> assign_commits_and_stats(commits(socket))
    |> noreply()
  end

  # Receive broadcasts when other clients update their state.
  @impl Phoenix.LiveView
  def handle_info({:changed_commit, commit}, socket) do
    commits = commits(socket) |> replace_commit(commit)
    {:noreply, assign_commits_and_stats(socket, commits)}
  end

  # Receive broadcasts when new commits arrive.
  @impl Phoenix.LiveView
  def handle_info({:new_commits, new_commits}, socket) do
    # Another option here would be to just reload the latest commits from DB.
    commits = Enum.slice(new_commits ++ commits(socket), 0, @max_commits)
    {:noreply, assign_commits_and_stats(socket, commits)}
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

  defp assign_filtered_projects(socket) do
    assign(socket, projects: projects_for_team(team(socket)))
  end

  defp projects_for_team("all"), do: :all

  defp projects_for_team(team) do
    Remit.Team.projects_for(team)
  end

  def assign_defaults(socket, session) do
    socket
    |> assign(username: github_login(session))
    |> assign(your_last_selected_commit_id: nil)
    |> assign(projects: :all)
    |> assign(team: "all")
    |> assign(all_teams: Remit.Team.get_all())
  end

  defp assign_and_broadcast_changed_commit(socket, commit) do
    commits = commits(socket) |> replace_commit(commit)

    Commits.broadcast_changed_commit(commit)

    socket
    |> assign_commits_and_stats(commits)
    |> assign_selected_id(commit.id)
  end

  defp assign_selected_id(socket, id) when is_integer(id), do: assign(socket, your_last_selected_commit_id: id)
  defp assign_selected_id(socket, id) when is_binary(id), do: assign_selected_id(socket, String.to_integer(id))

  defp assign_commits_and_stats(socket, commits) do
    claimed_projects = Remit.Team.claimed_projects()
    displayed_commits = commits |> Enum.filter(& in_selected_projects?(socket, &1) || Commit.unclaimed_project?(&1, claimed_projects))

    unreviewed_count = displayed_commits |> Enum.count(&(!&1.reviewed_at))
    my_unreviewed_count = displayed_commits |> Enum.count(&(!&1.reviewed_at && authored?(socket, &1)))

    commits = Commit.add_date_separators(commits)

    assign(socket, %{
      commits: commits,
      displayed_commits: displayed_commits,
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

  defp in_selected_projects?(socket, commit) do
    case projects(socket) do
      :all -> true
      projects -> Commit.in_any_project?(commit, projects)
    end
  end

  defp username(socket), do: socket.assigns.username
  defp commits(socket), do: socket.assigns.commits
  defp projects(socket), do: socket.assigns.projects
  defp team(socket), do: socket.assigns.team
end
