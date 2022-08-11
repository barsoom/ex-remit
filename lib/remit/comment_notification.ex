defmodule Remit.CommentNotification do
  @moduledoc false
  use Remit, :schema
  alias Remit.{Comment, Commit}

  schema "comment_notifications" do
    field :resolved_at, :utc_datetime_usec
    field :username, :string

    belongs_to :comment, Comment

    timestamps()
  end

  @type t() :: %__MODULE__{}

  @doc ~S"""
  Returns the list of coauthor usernames who have resolved their notifications
  on the same comment.
  """
  @spec resolved_coauthors(CommentNotification.t()) :: list(String.t())
  def resolved_coauthors(%CommentNotification{comment: %Comment{commit: %Commit{}, comment_notifications: others}} = notification) when is_list(others) do
    others
    |> Enum.filter(&resolved_by_coauthor?(notification, &1))
    |> Enum.map(&(&1.username))
  end

  def resolved_coauthors(_), do: [] # missing loaded assocs, cannot answer

  defp resolved_by_coauthor?(n, other_n) do
    other_n.resolved_at != nil
    && other_n.username in n.comment.commit.usernames
    && other_n.username != n.username
  end
end
