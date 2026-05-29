defmodule Remit.CommitsTest do
  use Remit.DataCase, async: true
  alias Remit.{Commits, Factory}

  describe "list_latest_shas" do
    test "returns up to the given number of recent SHAs" do
      Factory.insert!(:commit, sha: "abc1")
      # Not included.
      Factory.insert!(:commit, sha: "ffff", unlisted: true)
      Factory.insert!(:commit, sha: "abc2")

      assert Commits.list_latest_shas(1) == ["abc2"]
      assert Commits.list_latest_shas(2) == ["abc2", "abc1"]
      assert Commits.list_latest_shas(99) == ["abc2", "abc1"]
    end
  end

  describe "list_deployed_shas" do
    test "returns deployment info keyed by build commit sha and uses deployed repo when present" do
      _target_commit =
        Factory.insert!(:commit,
          sha: "buildsha1",
          repo: "build-repo",
          deployed_sha: "deployedsha1",
          deployed_repo: "target-repo",
          url: "http://example.com/buildsha1"
        )

      _fallback_commit =
        Factory.insert!(:commit,
          sha: "buildsha2",
          repo: "build-repo",
          deployed_sha: "deployedsha2",
          deployed_repo: nil,
          url: "http://example.com/buildsha2"
        )

      assert Commits.list_deployed_shas(["target-repo"]) == %{
               "buildsha1" => %{
                 url: "http://example.com/buildsha1",
                 repo: "target-repo",
                 deployed_sha: "deployedsha1"
               }
             }

      assert Commits.list_deployed_shas(["build-repo"]) == %{
               "buildsha1" => %{
                 url: "http://example.com/buildsha1",
                 repo: "target-repo",
                 deployed_sha: "deployedsha1"
               },
               "buildsha2" => %{
                 url: "http://example.com/buildsha2",
                 repo: "build-repo",
                 deployed_sha: "deployedsha2"
               }
             }
    end
  end

  describe "delete_reviewed_older_than_days" do
    test "deletes commits older than the given number of days, and their associated records" do
      # Since we can't (?) freeze time in this test, we make sure the newer record has a little margin.
      older_unreviewed_commit = Factory.insert!(:commit, inserted_at: days_and_seconds_ago(100, 1), reviewed_at: nil)

      older_reviewed_commit =
        Factory.insert!(:commit, inserted_at: days_and_seconds_ago(100, 1), reviewed_at: some_time())

      newer_reviewed_commit =
        Factory.insert!(:commit, inserted_at: days_and_seconds_ago(100, -5), reviewed_at: some_time())

      older_reviewed_commit_comment = Factory.insert!(:comment, commit: older_reviewed_commit)
      newer_reviewed_commit_comment = Factory.insert!(:comment, commit: newer_reviewed_commit)

      older_reviewed_commit_notification =
        Factory.insert!(:comment_notification, comment: older_reviewed_commit_comment)

      newer_reviewed_commit_notification =
        Factory.insert!(:comment_notification, comment: newer_reviewed_commit_comment)

      assert in_db?(older_unreviewed_commit)
      assert in_db?(older_reviewed_commit)
      assert in_db?(older_reviewed_commit_comment)
      assert in_db?(older_reviewed_commit_notification)
      assert in_db?(newer_reviewed_commit)
      assert in_db?(newer_reviewed_commit_comment)
      assert in_db?(newer_reviewed_commit_notification)

      Commits.delete_reviewed_older_than_days(100)

      assert in_db?(older_unreviewed_commit)
      refute in_db?(older_reviewed_commit)
      refute in_db?(older_reviewed_commit_comment)
      refute in_db?(older_reviewed_commit_notification)
      assert in_db?(newer_reviewed_commit)
      assert in_db?(newer_reviewed_commit_comment)
      assert in_db?(newer_reviewed_commit_notification)

      Commits.delete_reviewed_older_than_days(99)
      assert in_db?(older_unreviewed_commit)
      refute in_db?(newer_reviewed_commit)
      refute in_db?(newer_reviewed_commit_comment)
      refute in_db?(newer_reviewed_commit_notification)
    end

    defp in_db?(record), do: Repo.exists?(from record.__struct__, where: [id: ^record.id])

    defp some_time, do: DateTime.utc_now()

    defp days_and_seconds_ago(days, seconds) do
      DateTime.utc_now()
      |> DateTime.add(-days * 60 * 60 * 24)
      |> DateTime.add(-seconds)
    end
  end
end
