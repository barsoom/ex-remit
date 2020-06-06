defmodule Remit.IngestCommits do
  alias Remit.{Repo, Commits, Commit, Utils}

  def from_params(params) do
    build_commits(params)
    |> Enum.map(& Repo.insert!(&1))
    |> Enum.reverse()  # Inserted newest last, but shown newest first.
    |> Commits.broadcast_new_commits()
  end

  # Private

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
      committed_at: Utils.date_time_from_iso8601!(raw_committed_at),
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
end
