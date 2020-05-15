defmodule Remit.Commit do
  use Ecto.Schema
  import Ecto.Changeset

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
end
