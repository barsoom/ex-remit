defmodule Remit.Commit do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Remit.{Commit,Repo}

  @timestamps_opts [type: :utc_datetime]

  schema "commits" do
    field :sha, :string
    field :payload, :map
    field :review_started_at, :utc_datetime
    field :reviewed_at, :utc_datetime
    field :review_started_by_author_id, :id
    field :reviewed_by_author_id, :id

    belongs_to :author, Remit.Author

    timestamps()
  end

  def load_latest(count) do
    Repo.all(
      from c in Commit,
        limit: ^count,
        order_by: [desc: c.inserted_at],
        preload: :author
    )
  end

  def mark_as_reviewed!(id) do
    # TODO: Allow useconds in DB so we don't need this dance.
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.get_by(Commit, id: id) |> Ecto.Changeset.change(reviewed_at: now) |> Repo.update!()
  end

  def mark_as_unreviewed!(id) do
    Repo.get_by(Commit, id: id) |> Ecto.Changeset.change(reviewed_at: nil, review_started_at: nil) |> Repo.update!()
  end

  def mark_as_review_started!(id) do
    # TODO: Allow useconds in DB so we don't need this dance.
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.get_by(Commit, id: id) |> Ecto.Changeset.change(review_started_at: now) |> Repo.update!()
  end

  def repo_name(commit) do
    commit.payload |> get_in(["repository", "name"])
  end

  def commit_message(commit) do
    commit.payload |> Map.fetch!("message")
  end

  @doc false
  def changeset(commit, attrs) do
    commit
    |> cast(attrs, [:sha, :payload, :review_started_at, :reviewed_at, :author_id, :review_started_by_author_id, :reviewed_by_author_id, :inserted_at])
    |> validate_required([:sha, :payload])
  end

  def subscribe_to_changed_commits do
    Phoenix.PubSub.subscribe(Remit.PubSub, "commits")
  end

  def broadcast_changed_commit(commit) do
    Phoenix.PubSub.broadcast_from(Remit.PubSub, self(), "commits", {:changed_commit, commit})
  end
end
