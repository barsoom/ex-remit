defmodule Remit.CommentsTest do
  use Remit.DataCase, async: true
  alias Remit.{Comments, Factory}

  describe "list_notifications with :repo" do
    test "filters notifications by the commit's repo" do
      mine = Factory.insert!(:comment_notification, username: "octocat")

      mine.comment.commit
      |> Ecto.Changeset.change(repo: "repo-a")
      |> Repo.update!()

      other = Factory.insert!(:comment_notification, username: "octocat")

      other.comment.commit
      |> Ecto.Changeset.change(repo: "repo-b")
      |> Repo.update!()

      result =
        Comments.list_notifications(
          username: "octocat",
          resolved_filter: "unresolved",
          user_filter: "for_me",
          repo: "repo-a",
          limit: 10
        )

      assert Enum.map(result, & &1.id) == [mine.id]
    end

    test "does not filter by repo when option is omitted" do
      a = Factory.insert!(:comment_notification, username: "octocat")
      b = Factory.insert!(:comment_notification, username: "octocat")

      result =
        Comments.list_notifications(
          username: "octocat",
          resolved_filter: "unresolved",
          user_filter: "for_me",
          limit: 10
        )

      ids = Enum.map(result, & &1.id) |> Enum.sort()
      assert ids == Enum.sort([a.id, b.id])
    end
  end
end
