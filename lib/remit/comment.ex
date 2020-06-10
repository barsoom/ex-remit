defmodule Remit.Comment do
  use Ecto.Schema
  import Ecto.Query
  alias Remit.{Commit, Comment, CommentNotification}

  @timestamps_opts [type: :utc_datetime_usec]

  schema "comments" do
    field :github_id, :integer
    field :commit_sha, :string
    field :body, :string
    field :commented_at, :utc_datetime_usec
    field :commenter_username, :string
    field :path, :string
    field :position, :integer
    field :url, :string
    field :payload, :map

    has_many :comment_notifications, CommentNotification
    belongs_to :commit, Commit, foreign_key: :commit_sha, references: :sha, define_field: false

    timestamps()
  end

  def other_comments_in_the_same_thread(%Comment{path: nil} = comment) do
    from c in other_comments_on_the_same_commit(comment),
      where: is_nil(c.path)
  end
  def other_comments_in_the_same_thread(%Comment{path: path, position: position} = comment) do
    from c in other_comments_on_the_same_commit(comment),
      where: c.path == ^path and c.position == ^position
  end

  # Private

  defp other_comments_on_the_same_commit(comment) do
    from c in Comment,
      where: c.commit_sha == ^comment.commit_sha,
      where: c.id != ^comment.id
  end
end
