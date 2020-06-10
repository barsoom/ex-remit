defmodule Remit.CommentNotification do
  use Remit, :schema
  alias Remit.Comment

  schema "comment_notifications" do
    field :resolved_at, :utc_datetime_usec
    field :username, :string

    belongs_to :comment, Comment

    timestamps()
  end
end
