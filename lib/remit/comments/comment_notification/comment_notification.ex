defmodule Remit.Comments.CommentNotification do
  use Remit, :schema
  alias Remit.Comments.Comment

  schema "comment_notifications" do
    field :resolved_at, :utc_datetime_usec
    field :username, :string

    belongs_to :comment, Comment

    timestamps()
  end

  def partial_notifications_with_limit(limit) do
    from n in __MODULE__,
       limit: ^limit,
       join: c in assoc(n, :comment),
       preload: [comment: {c, :commit}]
  end
end
