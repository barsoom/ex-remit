defmodule Remit.Commit do
  use Remit, :schema

  schema "commits" do
    field :sha, :string
    field :author_email, :string
    field :usernames, {:array, :string}
    field :owner, :string
    field :repo, :string
    field :message, :string
    field :committed_at, :utc_datetime_usec
    field :url, :string
    field :payload, :map

    field :review_started_at, :utc_datetime_usec
    field :reviewed_at, :utc_datetime_usec
    field :review_started_by_email, :string
    field :reviewed_by_email, :string

    field :date_separator_before, :date, virtual: true

    timestamps()
  end

  def latest(count), do: from Commit, limit: ^count, order_by: [desc: :id]

  def authored_by?(_commit, nil), do: false
  def authored_by?(commit, username), do: commit.usernames |> Enum.map(&String.downcase/1) |> Enum.member?(String.downcase(username))

  def being_reviewed_by?(%Commit{review_started_by_email: email}, email) when not is_nil(email), do: true
  def being_reviewed_by?(_, _), do: false

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
