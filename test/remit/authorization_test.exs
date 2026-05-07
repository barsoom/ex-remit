defmodule Remit.AuthorizationTest do
  use Remit.DataCase, async: false
  alias Remit.{Authorization, CommentNotification, Factory}

  describe "can_review_commit?/3 team and authorship rules for start_review" do
    test "returns false when username is nil" do
      commit = Factory.build(:commit, repo: "anything")
      refute Authorization.can_review_commit?("start_review", commit, nil)
    end

    test "returns true when no teams own the project" do
      commit = Factory.build(:commit, repo: "ownerless")
      assert Authorization.can_review_commit?("start_review", commit, "anyone")
    end

    test "returns true for a team member of an owning team" do
      Factory.insert!(:team,
        slug: "alpha",
        projects: ["myproject"],
        review_access: :team,
        usernames: ["alice"]
      )

      commit = Factory.build(:commit, repo: "myproject")

      assert Authorization.can_review_commit?("start_review", commit, "alice")
      refute Authorization.can_review_commit?("start_review", commit, "bob")
    end

    test "returns true for any user when team is public-access" do
      Factory.insert!(:team,
        slug: "beta",
        projects: ["pubproject"],
        review_access: :public,
        usernames: ["alice"]
      )

      commit = Factory.build(:commit, repo: "pubproject")

      assert Authorization.can_review_commit?("start_review", commit, "anyone")
    end

    test "returns false for a solo-authored own commit, even on a public project" do
      commit = Factory.build(:commit, repo: "ownerless", usernames: ["alice"])
      refute Authorization.can_review_commit?("start_review", commit, "alice")
      refute Authorization.can_review_commit?("start_review", commit, "ALICE")
    end

    test "returns false for a Co-authored-by trailer on own commit" do
      commit =
        Factory.build(:commit,
          repo: "ownerless",
          usernames: ["someoneelse"],
          message: Faker.message_with_co_authors("Some message", ["alice"])
        )

      refute Authorization.can_review_commit?("start_review", commit, "alice")
    end

    test "returns false for own commit even when on the owning team" do
      Factory.insert!(:team,
        slug: "alpha",
        projects: ["myproject"],
        review_access: :team,
        usernames: ["alice"]
      )

      commit = Factory.build(:commit, repo: "myproject", usernames: ["alice"])
      refute Authorization.can_review_commit?("start_review", commit, "alice")
    end
  end

  describe "can_review_commit?/3 review-state rules" do
    test "a new commit can be started or reviewed, but not reopened" do
      commit = Factory.build(:commit, repo: "ownerless")

      assert Authorization.can_review_commit?("start_review", commit, "alice")
      assert Authorization.can_review_commit?("mark_reviewed", commit, "alice")
      refute Authorization.can_review_commit?("mark_unreviewed", commit, "alice")
    end

    test "only the active reviewer can finish or cancel a review in progress, and nobody can start it again" do
      commit =
        Factory.build(:commit,
          repo: "ownerless",
          review_started_at: DateTime.utc_now(),
          review_started_by_username: "alice"
        )

      refute Authorization.can_review_commit?("start_review", commit, "alice")
      assert Authorization.can_review_commit?("mark_reviewed", commit, "alice")
      assert Authorization.can_review_commit?("mark_unreviewed", commit, "alice")

      for action <- ~w(start_review mark_reviewed mark_unreviewed) do
        refute Authorization.can_review_commit?(action, commit, "bob")
      end
    end

    test "an author who is somehow the active reviewer can cancel but not finish the review" do
      commit =
        Factory.build(:commit,
          repo: "ownerless",
          usernames: ["alice"],
          review_started_at: DateTime.utc_now(),
          review_started_by_username: "alice"
        )

      refute Authorization.can_review_commit?("mark_reviewed", commit, "alice")
      assert Authorization.can_review_commit?("mark_unreviewed", commit, "alice")
    end

    test "a reviewed commit can only be reopened, by anyone but its author" do
      commit =
        Factory.build(:commit,
          repo: "ownerless",
          usernames: ["carol"],
          reviewed_at: DateTime.utc_now(),
          reviewed_by_username: "alice"
        )

      refute Authorization.can_review_commit?("start_review", commit, "bob")
      refute Authorization.can_review_commit?("mark_reviewed", commit, "bob")
      assert Authorization.can_review_commit?("mark_unreviewed", commit, "bob")
      refute Authorization.can_review_commit?("mark_unreviewed", commit, "carol")
    end

    test "reopening a reviewed commit doesn't require being on the owning team" do
      Factory.insert!(:team, slug: "alpha", projects: ["myproject"], review_access: :team, usernames: ["alice"])
      commit = Factory.build(:commit, repo: "myproject", reviewed_at: DateTime.utc_now(), reviewed_by_username: "alice")

      assert Authorization.can_review_commit?("mark_unreviewed", commit, "bob")
    end
  end

  describe "can_resolve_notification?/2" do
    test "returns false when username is nil" do
      assert Authorization.can_resolve_notification?(%CommentNotification{username: "alice"}, nil) ==
               false
    end

    test "returns true when username matches the notification recipient (case-insensitive)" do
      n = %CommentNotification{username: "Alice"}
      assert Authorization.can_resolve_notification?(n, "alice")
      assert Authorization.can_resolve_notification?(n, "ALICE")
    end

    test "returns false when username does not match the notification recipient" do
      n = %CommentNotification{username: "alice"}
      refute Authorization.can_resolve_notification?(n, "bob")
    end
  end
end
