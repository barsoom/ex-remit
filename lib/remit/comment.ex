defmodule Remit.Comment do
  use Ecto.Schema
  import Ecto.Query
  alias Remit.{Repo, Commit, Comment, CommentNotification}

  @timestamps_opts [type: :utc_datetime]

  schema "comments" do
    field :github_id, :integer
    field :commit_sha, :string
    field :body, :string
    field :commented_at, :utc_datetime
    field :commenter_username, :string
    field :path, :string
    field :position, :integer
    field :url, :string

    has_many :comment_notifications, CommentNotification
    belongs_to :commit, Commit, foreign_key: :commit_sha, references: :sha, define_field: false

    timestamps()
  end

  def load_latest(count) do
    Repo.all(from c in Comment, limit: ^count, order_by: [desc: :id])
  end

  def load_other_comments_in_the_same_thread(%Comment{path: nil} = comment) do
    Repo.all(
      from c in other_comments_on_the_same_commit(comment),
        where: is_nil(c.path)
    )
  end
  def load_other_comments_in_the_same_thread(%Comment{path: path, position: position} = comment) do
    Repo.all(
      from c in other_comments_on_the_same_commit(comment),
        where: c.path == ^path and c.position == ^position
    )
  end

  def subscribe, do: Phoenix.PubSub.subscribe(Remit.PubSub, "comments")

  def broadcast_new_comment(comment) do
    Phoenix.PubSub.broadcast_from(Remit.PubSub, self(), "comments", {:new_comment, comment})
  end

  # Private

  defp other_comments_on_the_same_commit(comment) do
    from c in Comment,
      where: c.commit_sha == ^comment.commit_sha,
      where: c.id != ^comment.id
  end
end
