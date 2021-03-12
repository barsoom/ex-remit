defmodule Remit.Comments.Comments do
  alias Remit.Comments.{ Comment, CommentNotification}
  alias Remit.Repo
  import Ecto.Query

  def list_notifications(opts) when is_list(opts) do
    do_list_notifications(Enum.into(opts, %{}))
  end

  def list_other_comments_in_the_same_thread(comment) do
    comment
    |> Comment.other_comments_in_the_same_thread()
    |> Repo.all()
  end

  def resolve(id) do
    now = DateTime.utc_now()
    comment =
      Repo.get_by(CommentNotification, id: id)
      |> Ecto.Changeset.change(resolved_at: now)
      |> Repo.update!()

    broadcast_change()

    comment
  end

  def unresolve(id) do
    comment =
      Repo.get_by(CommentNotification, id: id)
      |> Ecto.Changeset.change(resolved_at: nil)
      |> Repo.update!()

    broadcast_change()

    comment
  end

  def subscribe, do: Phoenix.PubSub.subscribe(Remit.PubSub, "comments")

  def broadcast_change do
    Phoenix.PubSub.broadcast_from!(Remit.PubSub, self(), "comments", :comments_changed)
  end

  # Private

  defp do_list_notifications(%{username: username, resolved_filter: resolved_filter, user_filter: user_filter, limit: limit}) do
    notifications_query = CommentNotification.partial_notifications_with_limit(limit)

    notifications_query
    |> resolve_filter(resolved_filter)
    |> resolve_user_type(username, user_filter)
    |> Repo.all()
  end

  defp resolve_filter(query, "unresolved"), do: from(n in query, where: is_nil(n.resolved_at), order_by: [desc: :id])
  defp resolve_filter(query, "resolved"), do: from(n in query, where: not is_nil(n.resolved_at), order_by: [desc: :resolved_at])
  defp resolve_filter(query, "all"), do: from(query, order_by: [desc: :id])

  defp resolve_user_type(filtered_query, username, _user_filter) when is_nil(username), do: filtered_query
  defp resolve_user_type(filtered_query, _username, user_filter) when user_filter in ["all"], do: filtered_query

  defp resolve_user_type(filtered_query, username, user_filter) when user_filter in ["for_me"] do
    from n in filtered_query,
         where: fragment("LOWER(?)", n.username) == ^String.downcase(username)
  end

  defp resolve_user_type(filtered_query, username, user_filter) when user_filter in ["by_me"] do
    from [n, c] in filtered_query,
         where: fragment("LOWER(?)", c.commenter_username) == ^String.downcase(username)
  end
end
