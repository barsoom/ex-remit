defmodule RemitWeb.CommentComponent do
  use RemitWeb, :live_component
  alias Remit.{Commit, Comment, Utils}

  # We get a comment URL via webhook, but the anchor used to be incorrect for line comments.
  # It's supposed to be fixed per 2021-10-04; if we like, we could look into using it.
  #
  # If comment 1 on commit A is open on GitHub and we click the link for comment 2 on commit A, Fluid.app will try to navigate to that anchor without reloading the page. But comment 2 may not have been present when the commit A page was loaded, so nothing happens. We add a `remit_anchorbuster` parameter (that GitHub ignores) to force navigation.
  defp github_url(%Comment{path: nil, github_id: id, commit: %Commit{sha: sha, owner: o, repo: r}}) do
    "https://github.com/#{o}/#{r}/commit/#{sha}?remit_anchorbuster=#{id}#commitcomment-#{id}"
  end

  defp github_url(%Comment{github_id: id, commit: %Commit{sha: sha, owner: o, repo: r}}) do
    "https://github.com/#{o}/#{r}/commit/#{sha}?remit_anchorbuster=#{id}#r#{id}"
  end

  defp comment_recipient_avatars(commit, comment, notification, opts) do
    comment_recipients(commit, comment, notification)
    |> Enum.sort()
    |> move_element_to_front(notification.username)
    |> Enum.map(&github_avatar(&1, :comment, opts))
  end

  # For commits authored by a group, display the entire group as a joint recipient of reviewer comments.
  # Comments made by authors are exempt because they would typically be made in response,
  # so the intended recipient is the reviewer and not the author group.
  defp comment_recipients(nil, _, notification), do: [notification.username] # a comment might not have its commit in the DB
  defp comment_recipients(commit, comment, notification) do
    sent_to_author = notification.username in commit.usernames
    sent_by_author = comment.commenter_username in commit.usernames
    if sent_to_author and not sent_by_author do
      commit.usernames
    else
      [notification.username]
    end
  end

  defp move_element_to_front([], _), do: []
  defp move_element_to_front([_] = list, _), do: list # special case to avoid wasted work
  defp move_element_to_front(list, element) do
    case Remit.ListExt.delete_check(list, element) do
      {true, rem} -> [element | rem]
      _ -> list # the element was not in the list, so don't touch the original
    end
  end

end
