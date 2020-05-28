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
      |> Repo.insert!
      |> Repo.preload(:commit)

    # Notify authors and previous commenters.

    previous_commenter_usernames =
      Comment.load_other_comments_in_the_same_thread(comment)
      |> Enum.map(& &1.commenter_username)

    (comment.commit.author_usernames ++ previous_commenter_usernames)
    |> Enum.reject(& &1 == comment.commenter_username)
    |> Enum.uniq()
    |> Enum.each(& Repo.insert!(%CommentNotification{comment: comment, username: &1}))

    Comment.broadcast_new_comment(comment)

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
      "url" => url,
      "author" => (%{
        "email" => author_email,
        "name" => author_name,
      } = author),
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
      author_usernames: usernames_from_author(author),
      message: message,
      committed_at: parse_time(raw_committed_at),
      url: url,
    }
  end

  defp usernames_from_author(%{"username" => username}), do: [ username ]
  defp usernames_from_author(%{"email" => email}) do
    email                 # foo+bar+baz@example.com
    |> String.split("@")  # foo+bar+baz, example.com
    |> hd                 # foo+bar+baz
    |> String.split("+")  # foo, bar, baz
    |> Enum.drop(1)       # bar, baz
  end

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
      commented_at: parse_time(raw_commented_at),
      commenter_username: username,
      path: path,
      position: position,
      url: url,
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
