defmodule Remit.IngestComment do
  alias Remit.{Repo, Comments, Comment, CommentNotification, Utils}

  def from_params(params) do
    comment =
      build_comment(params)
      |> Repo.insert!
      |> Repo.preload(:commit)

    # Notify authors and previous commenters.

    previous_commenter_usernames =
      Comments.list_other_comments_in_the_same_thread(comment)
      |> Enum.map(& &1.commenter_username)

    (comment.commit.author_usernames ++ previous_commenter_usernames)
    |> Enum.reject(& &1 == comment.commenter_username)
    |> Enum.uniq()
    |> Enum.each(& Repo.insert!(%CommentNotification{comment: comment, username: &1}))

    Comments.broadcast_change()
  end

  # Private

  defp build_comment(%{
    "action" => "created",
    "comment" => %{
      "id" => id,
      "html_url" => url,
      "user" => %{
        "login" => username,
      },
      "commit_id" => sha,
      "position" => position,
      "path" => path,
      "created_at" => raw_commented_at,
      "body" => body,
    },
  }) do
    %Comment{
      github_id: id,
      commit_sha: sha,
      body: body,
      commented_at: Utils.date_time_from_iso8601!(raw_commented_at),
      commenter_username: username,
      path: path,
      position: position,
      url: url,
    }
  end
end
