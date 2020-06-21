defmodule Remit.IngestComment do
  alias Remit.{Repo, Comments, Comment, Commits, Commit, CommentNotification, Utils}

  @github_client Application.get_env(:remit, :github_api_client)

  def from_params(params) do
    fetch_commit_if_missing(params)

    comment =
      build_comment(params)
      |> Repo.insert!(on_conflict: :nothing, conflict_target: [:github_id])

    unless already_existed?(comment) do
      create_notifications(comment)
      Comments.broadcast_change()
    end

    comment
  end

  # Private

  def fetch_commit_if_missing(%{
    "action" => "created",
    "comment" => %{"commit_id" => sha},
    "repository" => %{
      "name" => repo,
      "owner" => %{"login" => owner},
    },
  }) do
    unless Commits.sha_exists?(sha) do
      @github_client.fetch_commit(owner, repo, sha)
      |> struct(unlisted: true)
      |> Repo.insert!()
    end
  end

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

  defp already_existed?(%Comment{id: nil}), do: true
  defp already_existed?(%Comment{}), do: false

  # Notify authors and previous commenters.
  defp create_notifications(comment) do
    comment = comment |> Repo.preload(:commit)

    lower_commenter_username = String.downcase(comment.commenter_username)
    commit_usernames = if comment.commit, do: comment.commit.usernames, else: []

    previous_commenter_usernames =
      Comments.list_other_comments_in_the_same_thread(comment)
      |> Enum.map(& &1.commenter_username)

    (commit_usernames ++ previous_commenter_usernames)
    |> Enum.reject(& String.downcase(&1) == lower_commenter_username)
    |> Enum.reject(&Commit.bot?/1)
    |> Enum.uniq()
    |> Enum.each(& Repo.insert!(%CommentNotification{comment: comment, username: &1}))
  end
end
