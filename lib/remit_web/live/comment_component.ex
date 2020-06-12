defmodule RemitWeb.CommentComponent do
  use RemitWeb, :live_component
  alias Remit.{Commit, Comment, Utils}

  # We get a comment URL via webhook, but the anchor is incorrect for line comments. This has been reported.
  defp github_url(%Comment{path: nil, github_id: id, commit: %Commit{sha: sha, owner: o, repo: r}}) do
    "https://github.com/#{o}/#{r}/commit/#{sha}#commitcomment-#{id}"
  end
  defp github_url(%Comment{github_id: id, commit: %Commit{sha: sha, owner: o, repo: r}}) do
    "https://github.com/#{o}/#{r}/commit/#{sha}#r#{id}"
  end
end
