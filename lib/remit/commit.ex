defmodule Remit.Commit do
  @moduledoc false
  use Remit, :schema

  schema "commits" do
    field :sha, :string
    field :usernames, {:array, :string}, default: []
    field :owner, :string
    field :repo, :string
    field :message, :string
    field :committed_at, :utc_datetime_usec
    field :url, :string
    field :payload, :map
    field :unlisted, :boolean

    field :review_started_at, :utc_datetime_usec
    field :reviewed_at, :utc_datetime_usec
    field :review_started_by_username, :string
    field :reviewed_by_username, :string

    field :date_separator_before, :date, virtual: true

    timestamps()
  end

  def latest_listed(q \\ __MODULE__, count), do: q |> latest(count) |> listed()
  def latest(q \\ __MODULE__, count), do: from(q, limit: ^count, order_by: [desc: :id])
  def listed(q \\ __MODULE__), do: from(q, where: [unlisted: false])

  def apply_filter(q, {:projects_of_team, team}) do
    # This includes projects that have not been assigned to any team, so that they don't slip through unseen by anybody.
    from c in q,
      where:
        c.repo in subquery(Remit.Team.team_projects_query(team)) or
          c.repo not in subquery(Remit.Team.all_claimed_projects_query())
  end

  def apply_filter(q, {:members_of_team, team}) do
    from c in q,
      where: fragment("? && ?", c.usernames, subquery(Remit.Team.team_members_query(team)))
  end

  def apply_filter(q, {:author, author}) do
    from c in q,
      where: ^author in c.usernames
  end

  def apply_filter(q, _), do: q

  def apply_reviewed_cutoff(q, filters) when is_list(filters),
    do: Enum.reduce(filters, q, &apply_reviewed_cutoff(&2, &1))

  def apply_reviewed_cutoff(q, {:reviewed_commit_cutoff_days, days}),
    do: q |> where([c], c.committed_at > ago(^days, "day"))

  def apply_reviewed_cutoff(q, {:reviewed_commit_cutoff_commits, commits}), do: q |> limit(^commits)
  def apply_reviewed_cutoff(q, _), do: q

  def authored_by?(_commit, nil), do: false

  def authored_by?(commit, username) do
    author_in_email?(commit, username) || author_in_commit_trailer?(commit, username)
  end

  def being_reviewed_by?(%Commit{review_started_by_username: username, reviewed_at: nil}, username)
      when not is_nil(username),
      do: true

  def being_reviewed_by?(_, _), do: false

  def oldest_unreviewed_for(_commits, nil), do: nil

  def oldest_unreviewed_for(commits, username) do
    commits
    |> Enum.reverse()
    |> Enum.find(
      &(!&1.reviewed_at && !authored_by?(&1, username) && (being_reviewed_by?(&1, username) || !&1.review_started_at))
    )
  end

  @overlong_in_review_over_minutes 15
  @overlong_in_review_over_seconds @overlong_in_review_over_minutes * 60
  def oldest_overlong_in_review_by(commits, username, now \\ DateTime.utc_now())
  def oldest_overlong_in_review_by(_commits, nil, _now), do: nil

  def oldest_overlong_in_review_by(commits, username, now) do
    commits
    |> Enum.reverse()
    |> Enum.find(
      &(being_reviewed_by?(&1, username) && DateTime.diff(now, &1.review_started_at) > @overlong_in_review_over_seconds)
    )
  end

  def bot?(username), do: String.ends_with?(username, "[bot]")

  def botless_username(username), do: String.replace_trailing(username, "[bot]", "")

  def message_summary(commit), do: commit.message |> String.split(~r/[\r\n]/) |> hd

  def add_date_separators(commits) do
    {new_commits, _acc} =
      Enum.map_reduce(commits, nil, fn commit, prev_date ->
        date = Remit.Utils.to_date(commit.committed_at)
        separator = if date == prev_date, do: nil, else: date
        commit = %{commit | date_separator_before: separator}
        {commit, date}
      end)

    new_commits
  end

  defp author_in_email?(commit, username) do
    commit.usernames
    |> Enum.map(&String.downcase/1)
    |> Enum.member?(String.downcase(username))
  end

  defp author_in_commit_trailer?(commit, username) do
    if commit.message,
      do: String.contains?(commit.message, "Co-authored-by: #{username}"),
      else: false
  end
end
