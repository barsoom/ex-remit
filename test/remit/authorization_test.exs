defmodule Remit.AuthorizationTest do
  use Remit.DataCase, async: false
  alias Remit.{Authorization, CommentNotification, Factory}

  test "returns false when username is nil" do
    commit = Factory.build(:commit, repo: "anything")
    refute Authorization.can_review_commit?(commit, nil)
  end

  test "returns true when no teams own the project" do
    commit = Factory.build(:commit, repo: "ownerless")
    assert Authorization.can_review_commit?(commit, "anyone")
  end

  test "returns true for a team member of an owning team" do
    Factory.insert!(:team,
      slug: "alpha",
      projects: ["myproject"],
      review_access: :team,
      usernames: ["alice"]
    )

    commit = Factory.build(:commit, repo: "myproject")

    assert Authorization.can_review_commit?(commit, "alice")
    refute Authorization.can_review_commit?(commit, "bob")
  end

  test "returns true for any user when team is public-access" do
    Factory.insert!(:team,
      slug: "beta",
      projects: ["pubproject"],
      review_access: :public,
      usernames: ["alice"]
    )

    commit = Factory.build(:commit, repo: "pubproject")

    assert Authorization.can_review_commit?(commit, "anyone")
  end

  test "returns false for a solo-authored own commit, even on a public project" do
    commit = Factory.build(:commit, repo: "ownerless", usernames: ["alice"])
    refute Authorization.can_review_commit?(commit, "alice")
    refute Authorization.can_review_commit?(commit, "ALICE")
  end

  test "returns false for a Co-authored-by trailer on own commit" do
    commit =
      Factory.build(:commit,
        repo: "ownerless",
        usernames: ["someoneelse"],
        message: Faker.message_with_co_authors("Some message", ["alice"])
      )

    refute Authorization.can_review_commit?(commit, "alice")
  end

  test "returns false for own commit even when on the owning team" do
    Factory.insert!(:team,
      slug: "alpha",
      projects: ["myproject"],
      review_access: :team,
      usernames: ["alice"]
    )

    commit = Factory.build(:commit, repo: "myproject", usernames: ["alice"])
    refute Authorization.can_review_commit?(commit, "alice")
  end

  test "raises when called with a non-Commit value" do
    not_a_commit = Map.from_struct(Factory.build(:commit))

    assert_raise FunctionClauseError, fn ->
      Authorization.can_review_commit?(not_a_commit, "alice")
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
