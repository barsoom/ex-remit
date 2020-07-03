defmodule RemitWeb.CommentComponent do
  use RemitWeb, :live_component
  alias Remit.{Commit, Comment, Utils}

  # We get a comment URL via webhook, but the anchor is incorrect for line comments. This has been reported.
  #
  # If comment 1 on commit A is open on GitHub and we click the link for comment 2 on commit A, Fluid.app will try to navigate to that anchor without reloading the page. But comment 2 may not have been present when the commit A page was loaded, so nothing happens. We add a `remit_anchorbuster` parameter (that GitHub ignores) to force navigation.
  defp github_url(%Comment{path: nil, github_id: id, commit: %Commit{sha: sha, owner: o, repo: r}}) do
    "https://github.com/#{o}/#{r}/commit/#{sha}?remit_anchorbuster=#{id}#commitcomment-#{id}"
  end
  defp github_url(%Comment{github_id: id, commit: %Commit{sha: sha, owner: o, repo: r}}) do
    "https://github.com/#{o}/#{r}/commit/#{sha}?remit_anchorbuster=#{id}#r#{id}"
  end
end
