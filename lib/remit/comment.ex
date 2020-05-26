defmodule Remit.Comment do
  use Ecto.Schema
  alias Remit.{Commit, CommentNotification}

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
end
