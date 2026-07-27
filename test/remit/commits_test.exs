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

  describe "list_latest/2 with advanced filters" do
    test "applies the repo filter before the limit, so older matches are still reachable" do
      # The regression this guards: filtering used to happen in the browser, after the query limit,
      # so a match older than the limit's worth of newer commits could never be seen.
      old_match = Factory.insert!(:commit, repo: "needle", sha: "old-match")
      for n <- 1..20, do: Factory.insert!(:commit, repo: "haystack", sha: "noise-#{n}")

      assert [] == Commits.list_latest([], 5) |> Enum.filter(&(&1.sha == "old-match"))
      assert [%{sha: "old-match"}] = Commits.list_latest([repos: ["needle"]], 5)

      assert old_match.id
    end

    test "filters by repo" do
      Factory.insert!(:commit, repo: "alpha", sha: "a")
      Factory.insert!(:commit, repo: "beta", sha: "b")

      assert ["a"] == Commits.list_latest([repos: ["alpha"]], 99) |> Enum.map(& &1.sha)
      assert ~w[b a] == Commits.list_latest([repos: ["alpha", "beta"]], 99) |> Enum.map(& &1.sha)
    end

    test "filters by author, matching any of the given usernames" do
      Factory.insert!(:commit, usernames: ["ann", "bob"], sha: "a")
      Factory.insert!(:commit, usernames: ["cyd"], sha: "b")

      assert ["a"] == Commits.list_latest([authors: ["ann"]], 99) |> Enum.map(& &1.sha)
      assert ["a"] == Commits.list_latest([authors: ["bob", "dan"]], 99) |> Enum.map(& &1.sha)
      assert [] == Commits.list_latest([authors: ["dan"]], 99) |> Enum.map(& &1.sha)
    end

    test "filters by search across message, sha, repo and usernames" do
      Factory.insert!(:commit, sha: "aaa1", message: "Fix the widget", repo: "one", usernames: ["ann"])
      Factory.insert!(:commit, sha: "bbb2", message: "Unrelated", repo: "two", usernames: ["bob"])

      assert ["aaa1"] == Commits.list_latest([search: "widget"], 99) |> Enum.map(& &1.sha)
      assert ["aaa1"] == Commits.list_latest([search: "AAA1"], 99) |> Enum.map(& &1.sha)
      assert ["aaa1"] == Commits.list_latest([search: "one"], 99) |> Enum.map(& &1.sha)
      assert ["aaa1"] == Commits.list_latest([search: "ann"], 99) |> Enum.map(& &1.sha)
      assert [] == Commits.list_latest([search: "nothing here"], 99) |> Enum.map(& &1.sha)
    end

    test "treats search wildcards as literals" do
      Factory.insert!(:commit, message: "100% done", sha: "a")
      Factory.insert!(:commit, message: "nope", sha: "b")

      assert ["a"] == Commits.list_latest([search: "100%"], 99) |> Enum.map(& &1.sha)
      assert [] == Commits.list_latest([search: "%zzz%"], 99) |> Enum.map(& &1.sha)
    end

    test "filters by reviewed status" do
      Factory.insert!(:commit, sha: "unrev", reviewed_at: nil)
      Factory.insert!(:commit, sha: "rev", reviewed_at: DateTime.utc_now())

      assert ["unrev"] == Commits.list_latest([reviewed: "unreviewed"], 99) |> Enum.map(& &1.sha)
      assert ["rev"] == Commits.list_latest([reviewed: "reviewed"], 99) |> Enum.map(& &1.sha)
      assert ~w[rev unrev] == Commits.list_latest([reviewed: "all"], 99) |> Enum.map(& &1.sha)
    end

    test "combines filters" do
      Factory.insert!(:commit, repo: "alpha", usernames: ["ann"], sha: "a")
      Factory.insert!(:commit, repo: "alpha", usernames: ["bob"], sha: "b")
      Factory.insert!(:commit, repo: "beta", usernames: ["ann"], sha: "c")

      assert ["a"] == Commits.list_latest([repos: ["alpha"], authors: ["ann"]], 99) |> Enum.map(& &1.sha)
    end

    test "filters by the projects of the selected teams, keeping unclaimed projects visible" do
      Factory.insert!(:commit, repo: "owned-by-us", sha: "a")
      Factory.insert!(:commit, repo: "owned-by-them", sha: "b")
      Factory.insert!(:commit, repo: "unclaimed", sha: "c")

      filter = {:projects_of_teams, {["owned-by-us"], ["owned-by-us", "owned-by-them"]}}

      assert ~w[c a] == Commits.list_latest([filter], 99) |> Enum.map(& &1.sha)
    end

    test "filters by the members of the selected teams" do
      Factory.insert!(:commit, usernames: ["ann"], sha: "a")
      Factory.insert!(:commit, usernames: ["bob"], sha: "b")

      assert ["a"] == Commits.list_latest([members_of_teams: ["ann", "cyd"]], 99) |> Enum.map(& &1.sha)
      assert [] == Commits.list_latest([members_of_teams: []], 99) |> Enum.map(& &1.sha)
    end
  end

  describe "distinct_repos/0" do
    test "returns each listed repo once, sorted" do
      Factory.insert!(:commit, repo: "beta")
      Factory.insert!(:commit, repo: "alpha")
      Factory.insert!(:commit, repo: "alpha")
      Factory.insert!(:commit, repo: "hidden", unlisted: true)

      assert Commits.distinct_repos() == ["alpha", "beta"]
    end

    test "is not capped by how many commits a page would show" do
      for n <- 1..30, do: Factory.insert!(:commit, repo: "repo-#{n}")

      assert length(Commits.distinct_repos()) == 30
    end
  end

  describe "distinct_authors/0" do
    test "returns each username once across all listed commits, sorted" do
      Factory.insert!(:commit, usernames: ["bob", "ann"])
      Factory.insert!(:commit, usernames: ["ann"])
      Factory.insert!(:commit, usernames: ["hidden"], unlisted: true)

      assert Commits.distinct_authors() == ["ann", "bob"]
    end
  end
end
