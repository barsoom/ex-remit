defmodule Remit.CommentsTest do
  use Remit.DataCase, async: true
  alias Remit.{Comments, Factory}

  defp list(opts) do
    [limit: 99, username: nil, resolved_filter: "all", user_filter: "all"]
    |> Keyword.merge(opts)
    |> Comments.list_notifications()
  end

  defp notification_for(body, attrs \\ []) do
    comment = Factory.insert!(:comment, body: body)
    Factory.insert!(:comment_notification, Keyword.merge([comment: comment], attrs))
  end

  describe "list_notifications/1 search" do
    test "applies the search before the limit, so older matches are still reachable" do
      # The regression this guards: search used to run in the browser, after the query limit.
      notification_for("the needle we want")
      for n <- 1..20, do: notification_for("noise #{n}")

      refute list(limit: 5) |> Enum.any?(&(&1.comment.body =~ "needle"))
      assert [%{comment: %{body: "the needle we want"}}] = list(limit: 5, search: "needle")
    end

    test "matches the comment body, case-insensitively" do
      notification_for("Fix the widget")
      notification_for("Unrelated")

      assert ["Fix the widget"] == list(search: "WIDGET") |> Enum.map(& &1.comment.body)
      assert [] == list(search: "nothing here") |> Enum.map(& &1.comment.body)
    end

    test "matches the commenter username and the commit sha" do
      commit = Factory.insert!(:commit, sha: "cafe1234")
      comment = Factory.insert!(:comment, commit: commit, commenter_username: "annabel", body: "hi")
      Factory.insert!(:comment_notification, comment: comment)

      assert ["hi"] == list(search: "annabel") |> Enum.map(& &1.comment.body)
      assert ["hi"] == list(search: "cafe12") |> Enum.map(& &1.comment.body)
    end

    test "treats search wildcards as literals" do
      notification_for("100% done")
      notification_for("nope")

      assert ["100% done"] == list(search: "100%") |> Enum.map(& &1.comment.body)
      assert [] == list(search: "%zzz%") |> Enum.map(& &1.comment.body)
    end

    test "an empty search is a no-op" do
      notification_for("anything")

      assert length(list(search: "")) == 1
      assert length(list([])) == 1
    end

    test "count_notifications counts every match, ignoring the display limit" do
      for n <- 1..8, do: notification_for("body #{n}")

      assert Comments.count_notifications(username: nil, resolved_filter: "all", user_filter: "all") == 8
      assert length(list(limit: 3)) == 3
    end

    test "count_notifications respects the search and resolved filters" do
      notification_for("needle one", resolved_at: nil)
      notification_for("needle two", resolved_at: DateTime.utc_now())
      notification_for("other", resolved_at: nil)

      base = [username: nil, user_filter: "all"]

      assert Comments.count_notifications(base ++ [resolved_filter: "all", search: "needle"]) == 2
      assert Comments.count_notifications(base ++ [resolved_filter: "unresolved", search: "needle"]) == 1
      assert Comments.count_notifications(base ++ [resolved_filter: "all"]) == 3
    end

    test "combines with the resolved filter" do
      notification_for("keep me", resolved_at: nil)
      notification_for("keep me too", resolved_at: DateTime.utc_now())

      assert ["keep me"] == list(search: "keep", resolved_filter: "unresolved") |> Enum.map(& &1.comment.body)
      assert ["keep me too"] == list(search: "keep", resolved_filter: "resolved") |> Enum.map(& &1.comment.body)
    end
  end
end
