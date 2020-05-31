defmodule Remit.Comments do
  use Ecto.Schema
  alias Remit.{Comment, CommentNotification}

  def list_notifications(opts) when is_list(opts) do
    list_notifications(Enum.into(opts, %{}))
  end

  def list_notifications(%{username: username, resolved_filter: resolved_filter, user_filter: resolved_filter}) do
  end
end
