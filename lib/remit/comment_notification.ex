defmodule Remit.CommentNotification do
  use Ecto.Schema
  alias Remit.Comment

  @timestamps_opts [type: :utc_datetime_usec]

  schema "comment_notifications" do
    field :resolved_at, :utc_datetime_usec
    field :username, :string

    belongs_to :comment, Comment

    timestamps()
  end
end
