defmodule Remit.Comment do
  use Ecto.Schema
  alias Remit.{Commit, Comment, CommentNotification}

  @timestamps_opts [type: :utc_datetime]

  schema "comments" do
    field :github_id, :integer
    field :commit_sha, :string
    field :body, :string
    field :commented_at, :utc_datetime
    field :commenter_username, :string
    field :path, :string
    field :position, :integer

    has_many :comment_notifications, CommentNotification
    belongs_to :commit, Commit, foreign_key: :commit_sha, references: :sha, define_field: false

    timestamps()
  end

  # If the file path and line position are identical, they're in the same thread.
  # Either in the same thread of line comments, or (if path and pos are nil), in the thread of non-line based commit comments.
  def same_thread?(
    %Comment{path: path, position: pos},
    %Comment{path: path, position: pos}
  ), do: true
  def same_thread?(_, _), do: false
end
