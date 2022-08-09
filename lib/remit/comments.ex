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

    get_notification = from n in CommentNotification, where: n.id == ^id, preload: [comment: :commit]

    resolve_notification = fn _, %{notification: notification} ->
      notification
      |> Ecto.Changeset.change(resolved_at: now)
      |> Repo.update()
    end

    resolve_comment = fn _, %{notification: notification} ->
      commit = notification.comment.commit
      authors = if commit, do: commit.usernames, else: []

      notification.comment
      |> Comment.resolve_changeset(notification.username, now, authors)
      |> Repo.update()
    end

    # The rule is that only the first resolver will get to also resolve the
    # comment. A higher isolation level than READ COMMITTED is required to
    # consistently enforce this without data races.
    #
    # The unlucky transaction will error out; Postgres transaction handling
    # guidelines recommend having a retry mechanism for such cases. This can be
    # added later though, since this is unlikely to be a frequent problem in
    # practice, and its only impact is UX.
    {:ok, result} = Multi.new()
                    |> Multi.run(:isolation_level, fn _, _ -> Repo.query("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ") end)
                    |> Multi.one(:notification, get_notification)
                    |> Multi.run(:updated_notification, resolve_notification)
                    |> Multi.run(:comment, resolve_comment)
                    |> Repo.transaction()

    broadcast_change()

    result.updated_notification
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
