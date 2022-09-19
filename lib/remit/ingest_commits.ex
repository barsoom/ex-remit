defmodule Remit.IngestCommits do
  @moduledoc ~S"""
  Handles new incoming commits from a webhook call.
  """
  alias Remit.{Repo, Commits, Commit, Utils}

  def from_params(params) do
    commits =
      build_commits(params)
      |> Enum.map(&Repo.insert!(&1, on_conflict: :nothing, conflict_target: [:sha]))
      # Conflicts get a nil ID.
      |> Enum.filter(& &1.id)
      # Inserted newest last, but shown newest first.
      |> Enum.reverse()

    Commits.broadcast_new_commits(commits)

    commits
  end

  # Private

  defp build_commits(%{
         "ref" => "refs/heads/" <> master_branch,
         "repository" => %{
           "master_branch" => master_branch,
           "name" => repo,
           "owner" => %{"name" => owner}
         },
         "commits" => commits
       }) do
    commits |> Enum.map(&build_commit(&1, owner, repo))
  end

  # Not on master branch.
  defp build_commits(_payload), do: []

  defp build_commit(
         %{
           "id" => sha,
           "url" => url,
           "author" => author,
           "committer" => committer,
           "message" => message,
           "timestamp" => raw_committed_at
         } = payload,
         owner,
         repo
       ) do
    %Commit{
      owner: owner,
      repo: repo,
      sha: sha,
      usernames: usernames(author, committer, message),
      message: message,
      committed_at: Utils.date_time_from_iso8601!(raw_committed_at),
      url: url,
      payload: payload
    }
  end

  defp usernames(author, committer, message) do
    (usernames_from(author) ++ usernames_from(committer) ++ usernames_from_commit_message(message))
    |> Enum.uniq_by(&String.downcase/1)
  end

  # Ignore "web-flow" committer, representing an edit made via the GitHub web UI.
  defp usernames_from(%{"username" => "web-flow"}), do: []

  defp usernames_from(%{"username" => username}), do: [username]
  defp usernames_from(%{"email" => email}), do: Utils.usernames_from_email(email)
  defp usernames_from_commit_message(commit_message), do: Remit.UsernamesFromCommitTrailers.call(commit_message)
end
