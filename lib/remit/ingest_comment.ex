defmodule Remit.IngestComment do
  alias Remit.{Repo, Comments, Comment, Commit, CommentNotification, Utils}

  def from_params(params) do
    comment =
      build_comment(params)
      |> Repo.insert!
      |> Repo.preload(:commit)

    # Notify authors and previous commenters.

    lower_commenter_username = String.downcase(comment.commenter_username)
    commit_usernames = if comment.commit, do: comment.commit.usernames, else: []

    previous_commenter_usernames =
      Comments.list_other_comments_in_the_same_thread(comment)
      |> Enum.map(& &1.commenter_username)

    (commit_usernames ++ previous_commenter_usernames)
    |> Enum.reject(& String.downcase(&1) == lower_commenter_username)
    |> Enum.reject(& Commit.bot?(&1))
    |> Enum.uniq()
    |> Enum.each(& Repo.insert!(%CommentNotification{comment: comment, username: &1}))

    Comments.broadcast_change()

    comment
  end

  # Private

  defp build_comment(%{
    "action" => "created",
    "comment" => %{
      "id" => id,
      "user" => %{
        "login" => username,
      },
      "commit_id" => sha,
      "position" => position,
      "path" => path,
      "created_at" => raw_commented_at,
      "body" => body,
    },
  } = payload) do
    %Comment{
      github_id: id,
      commit_sha: sha,
      body: body,
      commented_at: Utils.date_time_from_iso8601!(raw_commented_at),
      commenter_username: username,
      path: path,
      position: position,
      payload: payload,
    }
  end
end
