defmodule RemitWeb.CommitsLive do
  use RemitWeb, :live_view
  require Logger
  alias Remit.{Commits, Commit, GithubAuth, Ownership, Settings, Utils}

  @max_commits Application.compile_env(:remit, :max_commits)
  @overlong_check_frequency_secs 60

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    check_auth_key(session)

    if connected?(socket) do
      Commits.subscribe()
      GithubAuth.subscribe(session["session_id"])
      Settings.subscribe(session["session_id"])
      Ownership.subscribe()

      :timer.send_interval(
        @overlong_check_frequency_secs * 1000,
        self(),
        :check_for_overlong_reviewing
      )
    end

    socket
    |> assign_defaults(session)
    |> assign_all_teams()
    |> assign(page: 1, per_page: 20, commits_dbg: [])
    |> stream_commits(1)
    |> assign_stats()
    |> ok()
  end

  @impl Phoenix.LiveView
  def handle_event("next-page", _, socket) do
    {:noreply, stream_commits(socket, socket.assigns.page + 1)}
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, stream_commits(socket, 1)}
  end

  def handle_event("prev-page", _, socket) do
    if socket.assigns.page > 1 do
      {:noreply, stream_commits(socket, socket.assigns.page - 1)}
    else
      {:noreply, socket}
    end
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

  @impl Phoenix.LiveView
  def handle_info({:setting_updated, :reviewed_commit_cutoff, cutoff}, socket) do
    socket
    |> assign(reviewed_commit_cutoff: cutoff)
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
        |> stream(:commits_list, commits, at: 0)
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
    commits = Commits.list_latest(commit_filter(socket), nil)

    {:noreply,
     assign(socket,
       oldest_overlong_in_review_by_me: Commit.oldest_overlong_in_review_by(commits, username(socket))
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
    Logger.error("unexpected message #{inspect(message)}")
    {:noreply, socket}
  end

  def assign_defaults(socket, session) do
    socket
    |> assign(username: github_login(session))
    |> assign(your_last_selected_commit_id: nil)
    |> assign(projects_of_team: get_filter(session, "commits", "projects_of_team", "all"))
    |> assign(members_of_team: get_filter(session, "commits", "members_of_team", "all"))
    |> assign(reviewed_commit_cutoff: get_reviewed_commit_cutoff(session, %{"days" => 7, "commits" => 100}))
  end

  def assign_all_teams(socket) do
    socket
    |> assign(all_teams: Remit.Team.get_all())
  end

  # Private
  defp commit_filter(socket) do
    commit_filter_by_projects(projects_of_team(socket)) ++
      commit_filter_by_members(members_of_team(socket)) ++
      reviewed_commit_filter(reviewed_commit_cutoff(socket))
  end

  defp commit_filter_by_projects("all"), do: []
  defp commit_filter_by_projects(team), do: [projects_of_team: team]

  defp commit_filter_by_members("all"), do: []
  defp commit_filter_by_members(team), do: [members_of_team: team]

  defp reviewed_commit_filter(cutoff) do
    cutoff
    |> Enum.reduce([], fn {key, value}, filter -> reviewed_commit_filter(filter, key, value) end)
  end

  defp reviewed_commit_filter(acc, key, value)
  defp reviewed_commit_filter(acc, _, 0), do: acc
  defp reviewed_commit_filter(acc, "days", days), do: [{:reviewed_commit_cutoff_days, days} | acc]

  defp reviewed_commit_filter(acc, "commits", commits),
    do: [{:reviewed_commit_cutoff_commits, commits} | acc]

  def load_commits_for_display(socket) do
    Commits.list_latest(commit_filter(socket), @max_commits)
  end

  def stream_commits(socket, next_page) when next_page >= 1 do
    %{per_page: per_page, page: curr_page} = socket.assigns

    offset = (next_page - 1) * curr_page
    commits = Commits.list_latest(%{}, per_page, offset)

    # direction -1 append, 0 prepend
    {commits, direction, limit} =
      if next_page >= curr_page do
        {commits, -1, per_page * 4 - 1}
      else
        {Enum.reverse(commits), 0, per_page * 4}
      end

    case commits do
      [] ->
        socket
        |> assign(end_of_timeline?: direction == -1)
        |> stream(:commits_list, [])

      [_ | _] = commits ->
        socket
        |> assign(end_of_timeline?: false)
        |> assign(:page, next_page)
        |> stream(:commits_list, commits, at: direction, limit: limit)
    end
  end

  def assign_current_commits(socket) do
    socket
    |> stream(:commits_list, load_commits_for_display(socket), reset: true)
  end

  defp assign_and_broadcast_changed_commit(socket, commit) do
    Commits.broadcast_changed_commit(commit)

    socket
    |> update_commit(commit)
    |> assign_stats()
    |> assign_selected_id(commit.id)
  end

  defp assign_selected_id(socket, id) when is_integer(id),
    do: assign(socket, your_last_selected_commit_id: id)

  defp assign_selected_id(socket, id) when is_binary(id),
    do: assign_selected_id(socket, String.to_integer(id))

  defp update_commit(socket, commit) do
    socket
    |> replace_commit(commit)
  end

  defp assign_stats(socket) do
    commits = Commits.list_latest(commit_filter(socket), @max_commits)

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

  defp replace_commit(socket, commit) do
    socket |> stream_insert(:commits_list, commit, at: -1)
  end

  defp authored?(socket, commit), do: Commit.authored_by?(commit, username(socket))

  defp username(socket), do: socket.assigns.username
  defp commits(socket), do: socket.assigns.streams.commits_list
  defp projects_of_team(socket), do: socket.assigns.projects_of_team
  defp members_of_team(socket), do: socket.assigns.members_of_team
  defp reviewed_commit_cutoff(socket), do: socket.assigns.reviewed_commit_cutoff
end
