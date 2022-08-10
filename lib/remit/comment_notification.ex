defmodule Remit.CommentNotification do
  use Remit, :schema
  alias Remit.{Comment, Commit}

  schema "comment_notifications" do
    field :resolved_at, :utc_datetime_usec
    field :username, :string

    belongs_to :comment, Comment

    timestamps()
  end

  def resolved_by_coauthor?(%CommentNotification{comment: %Comment{commit: %Commit{}, comment_notifications: others}} = notification) when is_list(others) do
    others |> Enum.any?(&resolved_by_coauthor?(notification, &1))
  end

  def resolved_by_coauthor?(_), do: nil # missing loaded assocs, cannot answer

  defp resolved_by_coauthor?(n, other_n) do
    other_n.resolved_at != nil
    && other_n.username in n.comment.commit.usernames
    && other_n.username != n.username
  end
end
