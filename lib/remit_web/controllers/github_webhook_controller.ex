defmodule RemitWeb.GithubWebhookController do
  use RemitWeb, :controller
  alias Remit.{Repo, Commit, Comment, CommentNotification}

  def create(conn, params) do
    handle_event(conn, event_name(conn), params)
  end

  # Private

  defp handle_event(conn, "ping", _params) do
    conn |> text("pong")
  end

  # Pushed commits.
  defp handle_event(conn, "push", params) do
    commits =
      build_commits(params)
      |> Enum.map(& Repo.insert!(&1))

    commits
    |> Enum.reverse()  # Inserted newest last, but shown newest first.
    |> Commit.broadcast_new_commits()

    conn |> text("Thanks!")
  end

  # Commit comment.
  defp handle_event(conn, "commit_comment", params) do
    comment =
      build_comment(params)
      |> Repo.preload([commit: [:comments]])
      |> Repo.insert!

    # Notify committer(s).
    committer_names = comment.commit.author_name |> String.split(" and ")
    committer_names |> Enum.each(fn (committer_name) ->
      %CommentNotification{
        comment: comment,
        committer_name: committer_name,
      } |> Repo.insert!
    end)

    # Notify previous commenters in this thread.
    comment.commit.comments
    |> Enum.filter(& CommentNotification.notifiable_commenter?(comment, &1))
    |> Enum.map(& &1.commenter_username)
    |> Enum.uniq()
    |> Enum.each(fn (commenter_username) ->
      %CommentNotification{
        comment: comment,
        commenter_username: commenter_username,
      } |> Repo.insert!
    end)

    # TODO: Broadcast

    conn |> text("Thanks!")
  end

  defp build_commits(%{
    "ref" => "refs/heads/" <> master_branch,
    "repository" => %{
      "master_branch" => master_branch,
      "name" => repo,
      "owner" => %{"name" => owner},
    },
    "commits" => commits,
  }) do
    commits |> Enum.map(&build_commit(&1, owner, repo))
  end
  defp build_commits(_payload), do: []  # Not on master branch.

  defp build_commit(
    %{
      "id" => sha,
      "author" => %{"email" => author_email, "name" => author_name},
      "message" => message,
      "timestamp" => raw_committed_at,
    }, owner, repo)
  do
    %Commit{
      owner: owner,
      repo: repo,
      sha: sha,
      author_email: author_email,
      author_name: author_name,
      message: message,
      committed_at: parse_time(raw_committed_at),
    }
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
  }) do
    %Comment{
      github_id: id,
      commit_sha: sha,
      body: body,
      commented_at: parse_time(raw_commented_at),
      commenter_username: username,
      path: path,
      position: position,
    }
  end

  defp event_name(conn) do
    conn.req_headers
    |> Enum.into(%{})
    |> Map.fetch!("x-github-event")
  end

  defp parse_time(raw_time) do
    {:ok, time, _offset} = DateTime.from_iso8601(raw_time)
    time
  end
end
