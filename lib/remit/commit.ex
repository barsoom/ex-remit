defmodule Remit.Commit do
  use Ecto.Schema
  import Ecto.Query
  alias __MODULE__

  @timestamps_opts [type: :utc_datetime]

  schema "commits" do
    field :sha, :string
    field :author_email, :string
    field :author_name, :string
    field :author_usernames, {:array, :string}
    field :owner, :string
    field :repo, :string
    field :message, :string
    field :committed_at, :utc_datetime
    field :url, :string

    field :review_started_at, :utc_datetime
    field :reviewed_at, :utc_datetime
    field :review_started_by_email, :string
    field :reviewed_by_email, :string

    timestamps()
  end

  def latest(count), do: from Commit, limit: ^count, order_by: [desc: :id]

  def authored_by?(_commit, nil), do: false
  def authored_by?(commit, username), do: Enum.member?(commit.author_usernames, username)

  def being_reviewed_by?(%Commit{review_started_by_email: email}, email) when not is_nil(email), do: true
  def being_reviewed_by?(_, _), do: false

  def message_summary(commit), do: commit.message |> String.split(~r/\R/) |> hd
end
