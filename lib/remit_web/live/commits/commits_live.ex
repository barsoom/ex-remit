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
      Remit.Comments.subscribe()
      GithubAuth.subscribe(session["session_id"])
      Settings.subscribe(session["session_id"])
      Ownership.subscribe()
      :timer.send_interval(@overlong_check_frequency_secs * 1000, self(), :check_for_overlong_reviewing)
    end

    socket
    |> assign_defaults(session)
    |> assign_all_teams()
    |> assign_filter_options()
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
  def handle_event("set_filter", %{"commits-of-author" => author}, socket) do
    socket
    |> assign(commits_of_author: author)
    |> assign_current_commits()
    |> assign_stats()
    |> noreply()
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

  # Advanced filter bar. The hook persists these to the session itself (via /api/filter_preference,
  # same as the legacy filter links) and pushes them here so the query re-runs.
  @impl Phoenix.LiveView
  def handle_event("set_filters", params, socket) do
    socket
    |> assign(selected_repos: list_param(params, "repos"))
    |> assign(selected_authors: list_param(params, "authors"))
    |> assign(selected_project_teams: list_param(params, "project_teams"))
    |> assign(selected_member_teams: list_param(params, "member_teams"))
    |> assign(reviewed_filter: string_param(params, "reviewed", "all"))
    |> assign(search: string_param(params, "search", ""))
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

  @impl Phoenix.LiveView
  def handle_info({:setting_updated, :feature_flags, flags}, socket) do
    socket
    |> assign(features: flags)
    |> assign_filter_options()
    |> assign_current_commits()
    |> assign_stats()
    |> noreply()
  end

  def handle_info({:setting_updated, _, _}, socket), do: noreply(socket)

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

    commit_for_display? =
      if advanced_filters?(socket) do
        &matches_advanced_filters?(socket, &1)
      else
        projects_of_team = projects_of_team(socket)
        members_of_team = members_of_team(socket)
        author_filter = commits_of_author(socket)

        fn commit ->
          Ownership.claimed_by_team_or_unclaimed?(commit.repo, projects_of_team) &&
            Ownership.authors_in_team?(commit.usernames, members_of_team) &&
            commit_matches_author_filter?(commit, author_filter)
        end
      end

    case Enum.filter(new_commits, commit_for_display?) do
      [] ->
        # the new commits are not part of the current filter, skip all updates
        noreply(socket)

      commits ->
        socket
        |> assign_commits(Enum.slice(commits ++ commits(socket), 0, @max_commits))
        |> assign_stats()
        |> assign_comment_counts()
        |> noreply()
    end
  end

  def handle_info(:comments_changed, socket) do
    socket |> assign_comment_counts() |> noreply()
  end

  def handle_info(:ownership_changed, socket) do
    socket
    |> assign_all_teams()
    |> assign_filter_options()
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
    Logger.error("unexpected message #{inspect(message)}")
    {:noreply, socket}
  end

  def assign_defaults(socket, session) do
    socket
    |> assign(username: github_login(session))
    |> assign(your_last_selected_commit_id: nil)
    |> assign(commits_of_author: "all")
    |> assign(projects_of_team: get_filter(session, "commits", "projects_of_team", "all"))
    |> assign(members_of_team: get_filter(session, "commits", "members_of_team", "all"))
    |> assign(reviewed_commit_cutoff: get_reviewed_commit_cutoff(session))
    |> assign(features: get_feature_flags(session))
    |> assign(comment_counts: %{})
    |> assign(selected_repos: get_filter(session, "commits", "repos", []))
    |> assign(selected_authors: get_filter(session, "commits", "authors", []))
    |> assign(selected_project_teams: get_filter(session, "commits", "project_teams", []))
    |> assign(selected_member_teams: get_filter(session, "commits", "member_teams", []))
    |> assign(reviewed_filter: get_filter(session, "commits", "reviewed", "all"))
    |> assign(search: get_filter(session, "commits", "search", ""))
  end

  def assign_all_teams(socket) do
    teams = Remit.Team.get_all()

    socket
    |> assign(all_teams: teams)
    |> assign(teams_by_project: teams_by_project(teams))
  end

  # Dropdown options come from their own queries so they aren't capped by @max_commits.
  def assign_filter_options(socket) do
    if socket.assigns.features["advanced_filters"] do
      socket
      |> assign(all_repos: Commits.distinct_repos())
      |> assign(all_authors: Commits.distinct_authors())
    else
      socket
      |> assign(all_repos: [])
      |> assign(all_authors: [])
    end
  end

  # Private
  defp commit_filter(socket) do
    if advanced_filters?(socket) do
      advanced_commit_filter(socket)
    else
      legacy_commit_filter(socket)
    end
  end

  defp legacy_commit_filter(socket) do
    commit_filter_by_projects(projects_of_team(socket)) ++
      commit_filter_by_members(members_of_team(socket)) ++
      reviewed_commit_filter(reviewed_commit_cutoff(socket)) ++
      commit_filter_by_author(commits_of_author(socket))
  end

  defp advanced_commit_filter(socket) do
    reviewed_commit_filter(reviewed_commit_cutoff(socket)) ++
      repos_filter(socket.assigns.selected_repos) ++
      authors_filter(socket.assigns.selected_authors) ++
      project_teams_filter(socket) ++
      member_teams_filter(socket) ++
      reviewed_status_filter(socket.assigns.reviewed_filter) ++
      search_filter(socket.assigns.search)
  end

  defp repos_filter([]), do: []
  defp repos_filter(repos), do: [{:repos, repos}]

  defp authors_filter([]), do: []
  defp authors_filter(authors), do: [{:authors, authors}]

  defp reviewed_status_filter(status) when status in ["reviewed", "unreviewed"], do: [{:reviewed, status}]
  defp reviewed_status_filter(_), do: []

  defp search_filter(term) when is_binary(term) do
    case String.trim(term) do
      "" -> []
      trimmed -> [{:search, trimmed}]
    end
  end

  defp search_filter(_), do: []

  defp project_teams_filter(socket) do
    case socket.assigns.selected_project_teams do
      [] ->
        []

      slugs ->
        teams = socket.assigns.all_teams
        [{:projects_of_teams, {projects_of(teams, slugs), all_claimed_projects(teams)}}]
    end
  end

  defp member_teams_filter(socket) do
    case socket.assigns.selected_member_teams do
      [] -> []
      slugs -> [{:members_of_teams, members_of(socket.assigns.all_teams, slugs)}]
    end
  end

  defp projects_of(teams, slugs) do
    teams |> Enum.filter(&(&1.slug in slugs)) |> Enum.flat_map(&(&1.projects || [])) |> Enum.uniq()
  end

  defp members_of(teams, slugs) do
    teams |> Enum.filter(&(&1.slug in slugs)) |> Enum.flat_map(&(&1.usernames || [])) |> Enum.uniq()
  end

  defp all_claimed_projects(teams), do: teams |> Enum.flat_map(&(&1.projects || [])) |> Enum.uniq()

  defp list_param(params, key) do
    case Map.get(params, key) do
      list when is_list(list) -> Enum.filter(list, &is_binary/1)
      _ -> []
    end
  end

  defp string_param(params, key, default) do
    case Map.get(params, key) do
      value when is_binary(value) -> value
      _ -> default
    end
  end

  defp commit_filter_by_author("all"), do: []
  defp commit_filter_by_author(author), do: [author: author]

  defp commit_filter_by_projects("all"), do: []
  defp commit_filter_by_projects(team), do: [projects_of_team: team]

  defp commit_filter_by_members("all"), do: []
  defp commit_filter_by_members(team), do: [members_of_team: team]

  defp reviewed_commit_filter(cutoff) do
    # Each half of the cutoff is applied only when its checkbox is on. A non-positive number counts
    # as off too, so sessions predating the checkboxes keep working.
    cutoff_entry(:reviewed_commit_cutoff_days, cutoff, "days") ++
      cutoff_entry(:reviewed_commit_cutoff_commits, cutoff, "commits")
  end

  defp cutoff_entry(filter_key, cutoff, key) do
    if cutoff_enabled?(cutoff, key), do: [{filter_key, cutoff[key]}], else: []
  end

  def load_commits_for_display(socket) do
    Commits.list_latest(commit_filter(socket), @max_commits)
  end

  def assign_current_commits(socket) do
    socket
    |> assign_commits(load_commits_for_display(socket))
    |> assign_truncation()
    |> assign_comment_counts()
  end

  # The list is always capped at @max_commits, whatever the cutoff settings say. Say so when it happens
  defp assign_truncation(socket) do
    shown = length(commits(socket))

    if shown < @max_commits do
      assign(socket, truncated?: false, total_matching: shown, max_commits: @max_commits)
    else
      assign(socket,
        truncated?: true,
        total_matching: Commits.count_latest(commit_filter(socket)),
        max_commits: @max_commits
      )
    end
  end

  defp assign_comment_counts(socket) do
    counts =
      if socket.assigns.features["comment_count_badge"] do
        shas = commits(socket) |> Enum.map(& &1.sha) |> Enum.filter(& &1)
        Remit.Comments.count_by_commit_sha(shas)
      else
        %{}
      end

    assign(socket, comment_counts: counts)
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

  defp commit_matches_author_filter?(_commit, "all"), do: true
  defp commit_matches_author_filter?(commit, author), do: Commit.authored_by?(commit, author)

  # Mirrors advanced_commit_filter/1 for commits arriving over PubSub, so we don't hit the DB once
  # per connected client. Incoming commits are always unreviewed.
  defp matches_advanced_filters?(socket, commit) do
    %{
      selected_repos: repos,
      selected_authors: authors,
      selected_project_teams: project_slugs,
      selected_member_teams: member_slugs,
      reviewed_filter: reviewed_filter,
      search: search,
      all_teams: teams
    } = socket.assigns

    usernames = commit.usernames || []

    (repos == [] or commit.repo in repos) and
      (authors == [] or Enum.any?(usernames, &(&1 in authors))) and
      (project_slugs == [] or
         commit.repo in projects_of(teams, project_slugs) or
         commit.repo not in all_claimed_projects(teams)) and
      (member_slugs == [] or Enum.any?(usernames, &(&1 in members_of(teams, member_slugs)))) and
      reviewed_filter != "reviewed" and
      matches_search?(commit, search)
  end

  defp matches_search?(commit, search) do
    case String.trim(search || "") do
      "" ->
        true

      term ->
        term = String.downcase(term)

        [commit.message, commit.sha, commit.repo | commit.usernames || []]
        |> Enum.any?(&(is_binary(&1) and String.contains?(String.downcase(&1), term)))
    end
  end

  defp advanced_filters?(socket), do: socket.assigns.features["advanced_filters"]

  defp authored?(socket, commit), do: Commit.authored_by?(commit, username(socket))

  defp teams_by_project(teams) do
    Enum.reduce(teams, %{}, fn team, acc ->
      Enum.reduce(team.projects || [], acc, fn project, acc ->
        update_in(acc, [Access.key(project, [])], &[team | &1])
      end)
    end)
  end

  defp can_review?(commit, username, teams_by_project)

  defp can_review?(_, nil, _), do: false

  defp can_review?(commit, username, teams_by_project) do
    teams = Map.get(teams_by_project, commit.repo, [])

    case teams do
      [] ->
        # no assigned owner for this project, treat as public
        true

      teams ->
        Enum.any?(teams, &Remit.Team.user_can_review_projects?(&1, username))
    end
  end

  defp username(socket), do: socket.assigns.username
  defp commits(socket), do: socket.assigns.commits
  defp projects_of_team(socket), do: socket.assigns.projects_of_team
  defp members_of_team(socket), do: socket.assigns.members_of_team
  defp commits_of_author(socket), do: socket.assigns.commits_of_author
  defp reviewed_commit_cutoff(socket), do: socket.assigns.reviewed_commit_cutoff
end
