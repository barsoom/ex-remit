defmodule Remit.CommentNotification do
  use Ecto.Schema
  alias Remit.Comment

  @timestamps_opts [type: :utc_datetime]

  schema "comment_notifications" do
    field :resolved_at, :utc_datetime
    field :username, :string

    belongs_to :comment, Comment

    timestamps()
  end
end
