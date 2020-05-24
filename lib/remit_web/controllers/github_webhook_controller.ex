defmodule RemitWeb.GithubWebhookController do
  use RemitWeb, :controller
  alias Remit.{Repo,Commit}

  def create(conn, params) do
    handle_event(conn, event_name(conn), params)
  end

  # Private

  defp handle_event(conn, "ping", _params) do
    conn |> text("pong")
  end

  # Pushed commits.
  defp handle_event(conn, "push", params) do
    build_commits(params)
    |> Enum.map(& Repo.insert!(&1))

    # TODO: Broadcast event

    conn |> text("Thanks!")
  end

  defp build_commits(%{
    "ref" => "refs/heads/" <> master_branch,
    "repository" => %{
      "master_branch" => master_branch,
      "name" => repo,
      "owner" => %{ "name" => owner },
    },
    "commits" => commits,
  }) do
    commits
    |> Enum.map(&build_commit(&1, owner, repo))
  end
  defp build_commits(_payload), do: nil  # Not on master branch.

  defp build_commit(%{
    "id" => sha,
    "author" => %{ "email" => author_email, "name" => author_name },
    "message" => message,
    "timestamp" => raw_committed_at,
  }, owner, repo) do
    {:ok, committed_at, _offset} = DateTime.from_iso8601(raw_committed_at)

    %Commit{
      owner: owner,
      repo: repo,
      sha: sha,
      author_email: author_email,
      author_name: author_name,
      message: message,
      committed_at: committed_at,
    }
  end

  defp event_name(conn) do
    conn.req_headers
    |> Enum.into(%{})
    |> Map.fetch!("x-github-event")
  end
end
