defmodule Remit.Comments do
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

  defp do_list_notifications(%{username: username, resolved_filter: resolved_filter, user_filter: user_filter, limit: limit}) do
    query =
      from n in CommentNotification,
        limit: ^limit,
        join: c in assoc(n, :comment),
        preload: [comment: {c, [:commit, :comment_notifications]}]

    query =
      case resolved_filter do
        "unresolved" -> from n in query, where: is_nil(n.resolved_at), order_by: [desc: :id]
        "resolved" -> from n in query, where: not is_nil(n.resolved_at), order_by: [desc: :resolved_at]
        "all" -> from query, order_by: [desc: :id]
      end

    query =
      case {username, user_filter} do
        {nil, _} -> query
        {_, "all"} -> query
        {_, "for_me"} -> from n in query, where: fragment("LOWER(?)", n.username) == ^String.downcase(username)
        {_, "by_me"} -> from [n, c] in query, where: fragment("LOWER(?)", c.commenter_username) == ^String.downcase(username)
      end

    Repo.all(query)
  end
end
