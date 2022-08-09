defmodule Remit.Comments do
  alias Remit.{Repo, Comment, CommentNotification}
  alias Ecto.Multi
  import Ecto.Query

  def list_notifications(opts) when is_list(opts) do
    do_list_notifications(Enum.into(opts, %{}))
  end

  def list_other_comments_in_the_same_thread(comment) do
    comment |> Comment.other_comments_in_the_same_thread() |> Repo.all()
  end

  def resolve(id) do
    now = DateTime.utc_now()

    notification = Repo.get_by(CommentNotification, id: id)
                   |> Repo.preload(comment: :commit)
    comment = notification.comment
    commit = comment.commit

    authors = if commit, do: commit.usernames, else: []

    {:ok, result} = Multi.new()
                    |> Multi.update(:notification, Ecto.Changeset.change(notification, resolved_at: now))
                    |> Multi.update(:comment, Comment.resolve_changeset(comment, notification.username, now, authors))
                    |> Repo.transaction()

    broadcast_change()

    result.notification
  end

  def unresolve(id) do
    notification = Repo.get_by(CommentNotification, id: id)
                   |> Repo.preload(:comment)
    comment = notification.comment

    {:ok, result} = Multi.new()
                    |> Multi.update(:notification, Ecto.Changeset.change(notification, resolved_at: nil))
                    |> Multi.update(:comment, Comment.unresolve_changeset(comment, notification.username))
                    |> Repo.transaction()

    broadcast_change()

    result.notification
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
        preload: [comment: {c, :commit}]

    query =
      case resolved_filter do
        "unresolved" -> from [n, c] in query, where: is_nil(n.resolved_at) and is_nil(c.resolved_at), order_by: [desc: :id]
        "resolved" -> from [n, c] in query, where: not (is_nil(n.resolved_at) and is_nil(c.resolved_at)), order_by: [desc: fragment("coalesce(?, ?)", field(n, :resolved_at), field(c, :resolved_at))]
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
