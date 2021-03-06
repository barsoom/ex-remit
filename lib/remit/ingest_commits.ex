defmodule Remit.IngestCommits do
  alias Remit.{Repo, Commits, Commit, Utils}

  def from_params(params) do
    commits =
      build_commits(params)
      |> Enum.map(& Repo.insert!(&1, on_conflict: :nothing, conflict_target: [:sha]))
      |> Enum.filter(& &1.id)  # Conflicts get a nil ID.
      |> Enum.reverse()  # Inserted newest last, but shown newest first.

    Commits.broadcast_new_commits(commits)

    commits
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
      "author" => author,
      "committer" => committer,
      "message" => message,
      "timestamp" => raw_committed_at,
    } = payload, owner, repo)
  do
    %Commit{
      owner: owner,
      repo: repo,
      sha: sha,
      usernames: usernames(author, committer),
      message: message,
      committed_at: Utils.date_time_from_iso8601!(raw_committed_at),
      url: url,
      payload: payload,
    }
  end

  defp usernames(author, committer) do
    (usernames_from(author) ++ usernames_from(committer))
    |> Enum.uniq_by(&String.downcase/1)
  end

  # Ignore "web-flow" committer, representing an edit made via the GitHub web UI.
  defp usernames_from(%{"username" => "web-flow"}), do: []

  defp usernames_from(%{"username" => username}), do: [username]
  defp usernames_from(%{"email" => email}), do: Utils.usernames_from_email(email)
end
