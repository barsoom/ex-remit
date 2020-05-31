defmodule Remit.Comments do
  alias Remit.{Repo, Comment, CommentNotification}
  import Ecto.Query

  def list_notifications(opts) when is_list(opts) do
    do_list_notifications(Enum.into(opts, %{}))
  end

  # Private

  defp do_list_notifications(%{username: username, resolved_filter: resolved_filter, user_filter: user_filter, limit: limit}) do
    query = from n in CommentNotification,
      limit: ^limit,
      join: c in assoc(n, :comment),
      preload: [comment: {c, :commit}]

    query =
      case resolved_filter do
        "unresolved" -> from n in query, where: is_nil(n.resolved_at), order_by: [asc: :id]
        "resolved" -> from n in query, where: not is_nil(n.resolved_at), order_by: [desc: :resolved_at]
        "all" -> from query, order_by: [desc: :id]
      end

    query =
      case {username, user_filter} do
        {nil, _} -> query
        {_, "all"} -> query
        {_, "for_me"} -> from n in query, where: n.username == ^username
        {_, "by_me"} -> from [n, c] in query, where: c.commenter_username == ^username
      end

    Repo.all(query)
  end
end
