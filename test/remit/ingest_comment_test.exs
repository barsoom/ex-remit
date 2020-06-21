defmodule Remit.IngestCommentTest do
  use Remit.DataCase
  import Ecto.Query
  alias Remit.{IngestComment, Repo, Commit, Comment, CommentNotification, Factory}

  # Also see GithubWebhookControllerTest.

  test "creates a notification for each author/commiter" do
    Factory.insert!(:commit, sha: "abc123", usernames: ["riffraff", "magenta"])

    build_params(sha: "abc123", username: "ada") |> IngestComment.from_params()

    assert Repo.exists?(from CommentNotification, where: [username: "riffraff"])
    assert Repo.exists?(from CommentNotification, where: [username: "magenta"])
  end

  test "creates a notification for each previous commenter in the same thread" do
    commit = Factory.insert!(:commit, sha: "abc123", usernames: ["riffraff", "magenta"])

    Factory.insert!(:comment, commit: commit, commenter_username: "rocky")
    Factory.insert!(:comment, commit: commit, commenter_username: "brad", path: "slab.ff", position: 10)
    Factory.insert!(:comment, commit: commit, commenter_username: "janet", path: "slab.ff", position: 15)

    new_unthreaded_comment = build_params(sha: "abc123", username: "frank", path: nil, position: nil) |> IngestComment.from_params()
    new_slab_10_comment = build_params(sha: "abc123", username: "frank", path: "slab.ff", position: 10) |> IngestComment.from_params()
    new_slab_15_comment = build_params(sha: "abc123", username: "frank", path: "slab.ff", position: 15) |> IngestComment.from_params()

    assert Repo.exists?(from CommentNotification, where: [comment_id: ^new_unthreaded_comment.id, username: "rocky"])
    refute Repo.exists?(from CommentNotification, where: [comment_id: ^new_unthreaded_comment.id, username: "brad"])
    refute Repo.exists?(from CommentNotification, where: [comment_id: ^new_unthreaded_comment.id, username: "janet"])

    refute Repo.exists?(from CommentNotification, where: [comment_id: ^new_slab_10_comment.id, username: "rocky"])
    assert Repo.exists?(from CommentNotification, where: [comment_id: ^new_slab_10_comment.id, username: "brad"])
    refute Repo.exists?(from CommentNotification, where: [comment_id: ^new_slab_10_comment.id, username: "janet"])

    refute Repo.exists?(from CommentNotification, where: [comment_id: ^new_slab_10_comment.id, username: "rocky"])
    refute Repo.exists?(from CommentNotification, where: [comment_id: ^new_slab_15_comment.id, username: "brad"])
    assert Repo.exists?(from CommentNotification, where: [comment_id: ^new_slab_15_comment.id, username: "janet"])
  end

  test "does not create notifications for bot authors" do
    Factory.insert!(:commit, sha: "abc123", usernames: ["riffraff", "robbie[bot]"])

    build_params(sha: "abc123", username: "ada") |> IngestComment.from_params()

    assert Repo.exists?(from CommentNotification, where: [username: "riffraff"])
    assert Repo.aggregate(CommentNotification, :count) == 1
  end


  test "does not create notifications for the comment author (case-insensitive)" do
    Factory.insert!(:commit, sha: "abc123", usernames: ["riffraff"])
    Factory.insert!(:comment, commit: nil, commit_sha: "abc123", commenter_username: "riffraff")

    build_params(sha: "abc123", username: "RiffRaff") |> IngestComment.from_params()

    refute Repo.exists?(from CommentNotification, where: [username: "riffraff"])
    refute Repo.exists?(from CommentNotification, where: [username: "RiffRaff"])
  end

  test "if not yet in DB, the commit-with-comments is fetched from GitHub and created it as unlisted" do
    Mox.expect(GitHubAPIClient.Mock, :fetch_commit, fn ("acme", "footguns", "abc123") ->
      Factory.build(:commit, sha: "abc123", usernames: ["frank"])
    end)

    Mox.expect(GitHubAPIClient.Mock, :fetch_comments_on_commit, fn (%Commit{sha: "abc123"}) ->
      [
        Factory.build(:comment, commit: nil, commit_sha: "abc123", github_id: 666, commenter_username: "rocky"),
        Factory.build(:comment, commit: nil, commit_sha: "abc123", github_id: 667, commenter_username: "brad"),
      ]
    end)

    build_params(sha: "abc123", github_id: 667, username: "brad") |> IngestComment.from_params()

    commit = Repo.one(from Commit, where: [sha: "abc123"])
    assert commit.unlisted

    assert Repo.exists?(from Comment, where: [github_id: 666])

    # Notifies the imported commit's author.
    assert Repo.exists?(from CommentNotification, where: [username: "frank"])

    # Notifies the imported comment's author.
    assert Repo.exists?(from CommentNotification, where: [username: "rocky"])
  end

  # Private

  defp build_params(opts) do
    sha = Keyword.fetch!(opts, :sha)
    username = Keyword.fetch!(opts, :username)
    path = Keyword.get(opts, :path, nil)
    position = Keyword.get(opts, :position, nil)
    github_id = Keyword.get_lazy(opts, :github_id, &Faker.number/0)

    # This is a subset of the actual payload.
    # Reference: https://developer.github.com/webhooks/event-payloads/#commit_comment
    %{
      "action" => "created",
      "comment" => %{
        "id" => github_id,
        "user" => %{
          "login" => username,
        },
        "commit_id" => sha,
        "position" => position,
        "path" => path,
        "created_at" => "2016-01-25T08:41:25+01:00",
        "body" => "Hello world!",
      },
      "repository" => %{
        "name" => "footguns",
        "owner" => %{"login" => "acme"},
      },
    }
  end
end
