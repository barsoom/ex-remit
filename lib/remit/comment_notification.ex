defmodule Remit.CommentNotification do
  use Ecto.Schema
  alias Remit.Comment

  @timestamps_opts [type: :utc_datetime]

  schema "comment_notifications" do
    field :resolved_at, :utc_datetime
    field :commenter_username, :string
    field :committer_name, :string

    belongs_to :comment, Comment

    timestamps()
  end

  # - Did not write the new comment, but did write an earlier one.
  # - It was in the same "comment thread" – had the same file path and position.
  def notifiable_commenter?(
    %Comment{commenter_username: u1, path: path, position: pos} = _new_comment,
    %Comment{commenter_username: u2, path: path, position: pos} = _earlier_comment
  ) when u1 != u2, do: true
  def notifiable_commenter?(_, _), do: false
end
