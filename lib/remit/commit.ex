defmodule Remit.Commit do
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
  def latest(q \\ __MODULE__, count), do: from q, limit: ^count, order_by: [desc: :id]
  def listed(q \\ __MODULE__), do: from q, where: [unlisted: false]

  def authored_by?(_commit, nil), do: false
  def authored_by?(commit, username), do: commit.usernames |> Enum.map(&String.downcase/1) |> Enum.member?(String.downcase(username))

  def being_reviewed_by?(%Commit{review_started_by_username: username, reviewed_at: nil}, username) when not is_nil(username), do: true
  def being_reviewed_by?(_, _), do: false

  def oldest_unreviewed_for(commits_sorted_newest_first, username) do
    commits_sorted_newest_first
    |> Enum.reverse()
    |> Enum.find(& !&1.reviewed_at && !authored_by?(&1, username) && (being_reviewed_by?(&1, username) || !&1.review_started_at))
  end

  @overlong_in_review_over_minutes 15
  @overlong_in_review_over_seconds @overlong_in_review_over_minutes * 60
  def overlong_in_review_by(commits, username, now \\ DateTime.utc_now()) do
    commits |> Enum.filter(fn commit ->
      being_reviewed_by?(commit, username) && DateTime.diff(now, commit.review_started_at) > @overlong_in_review_over_seconds
    end)
  end

  def bot?(username), do: String.ends_with?(username, "[bot]")

  def botless_username(username), do: String.replace_trailing(username, "[bot]", "")

  def message_summary(commit), do: commit.message |> String.split(~r/\R/) |> hd

  def add_date_separators(commits) do
    {new_commits, _acc} =
      Enum.map_reduce(commits, nil, fn (commit, prev_date) ->
        date = Remit.Utils.to_date(commit.committed_at)
        separator = if date == prev_date, do: nil, else: date
        commit = %{commit | date_separator_before: separator}
        {commit, date}
      end)

    new_commits
  end
end
