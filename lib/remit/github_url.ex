defmodule Remit.GithubUrl do
  alias Remit.Comment

  def commit_url(commit) do
    "https://github.com/#{commit.owner}/#{commit.repo}/commit/#{commit.sha}"
  end

  def comment_url(%Comment{github_id: id, commit: commit, path: nil}) do
    commit_url(commit) <> "#commitcomment-#{id}"
  end
  def comment_url(%Comment{github_id: id, commit: commit}) do
    commit_url(commit) <> "#r#{id}"
  end
end
