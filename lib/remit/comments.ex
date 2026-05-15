defmodule Remit.Comments do
  @moduledoc false
  alias Remit.{Repo, Comment, CommentNotification}
  import Ecto.Query

  def list_notifications(opts) when is_list(opts) do
    do_list_notifications(Enum.into(opts, %{}))
  end

  def list_other_comments_in_the_same_thread(comment) do
    comment |> Comment.other_comments_in_the_same_thread() |> Repo.all()
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

  defp do_list_notifications(%{
         username: username,
         resolved_filter: resolved_filter,
         user_filter: user_filter,
         limit: limit
       }) do
    order_by = if resolved_filter == "resolved", do: [desc: :resolved_at], else: [desc: :id]

    notifications_query(username, resolved_filter, user_filter)
    |> then(fn q ->
      from [n, c] in q, limit: ^limit, order_by: ^order_by, preload: [comment: {c, [:commit, :comment_notifications]}]
    end)
    |> Repo.all()
  end

  defp notifications_query(username, resolved_filter, user_filter) do
    query = from n in CommentNotification, join: c in assoc(n, :comment)

    query =
      case resolved_filter do
        "unresolved" -> from n in query, where: is_nil(n.resolved_at)
        "resolved" -> from n in query, where: not is_nil(n.resolved_at)
        "all" -> query
      end

    case {username, user_filter} do
      {nil, _} ->
        query

      {_, "all"} ->
        query

      {_, "for_me"} ->
        from n in query, where: fragment("LOWER(?)", n.username) == ^String.downcase(username)

      {_, "by_me"} ->
        from [n, c] in query, where: fragment("LOWER(?)", c.commenter_username) == ^String.downcase(username)
    end
  end
end
