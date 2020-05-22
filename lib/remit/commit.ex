defmodule Remit.Commit do
  use Ecto.Schema
  import Ecto.Query
  alias Remit.{Commit,Repo}

  @timestamps_opts [type: :utc_datetime]

  schema "commits" do
    field :sha, :string
    field :author_email, :string
    field :author_name, :string
    field :owner, :string
    field :repo, :string
    field :message, :string
    field :committed_at, :utc_datetime

    field :review_started_at, :utc_datetime
    field :reviewed_at, :utc_datetime
    field :review_started_by_email, :string
    field :reviewed_by_email, :string

    timestamps()
  end

  def load_latest(count) do
    Repo.all(
      from c in Commit,
        limit: ^count,
        order_by: [desc: c.inserted_at]
    )
  end

  def mark_as_reviewed!(id, reviewer_email) do
    # TODO: Allow useconds in DB so we don't need this dance.
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.get_by(Commit, id: id)
    |> Ecto.Changeset.change(reviewed_at: now, reviewed_by_email: reviewer_email)
    |> Repo.update!()
  end

  def mark_as_unreviewed!(id) do
    Repo.get_by(Commit, id: id)
    |> Ecto.Changeset.change(reviewed_at: nil, review_started_at: nil, reviewed_by_email: nil, review_started_by_email: nil)
    |> Repo.update!()
  end

  def mark_as_review_started!(id, reviewer_email) do
    # TODO: Allow useconds in DB so we don't need this dance.
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.get_by(Commit, id: id)
    |> Ecto.Changeset.change(review_started_at: now, review_started_by_email: reviewer_email)
    |> Repo.update!()
  end

  def authored_by?(_commit, nil), do: false
  def authored_by?(commit, name), do: String.contains?(commit.author_name, name)

  def subscribe_to_changed_commits do
    Phoenix.PubSub.subscribe(Remit.PubSub, "commits")
  end

  def broadcast_changed_commit(commit) do
    Phoenix.PubSub.broadcast_from(Remit.PubSub, self(), "commits", {:changed_commit, commit})
  end
end
