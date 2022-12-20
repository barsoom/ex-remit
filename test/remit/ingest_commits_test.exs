defmodule Remit.IngestCommitsTest do
  use Remit.DataCase
  import Ecto.Query
  alias Remit.{IngestCommits, Repo, Commit, Factory}

  # Also see GithubWebhookControllerTest.

  test "creates commits" do
    build_params(
      commits: [
        [sha: "abc123"]
      ]
    )
    |> IngestCommits.from_params()

    assert Repo.exists?(from Commit, where: [sha: "abc123"])
  end

  test "assigns usernames from author username and committer username" do
    [commit] = build_params(commits: [[author_username: "foo", committer_username: "bar"]]) |> IngestCommits.from_params()
    assert commit.usernames == ["foo", "bar"]

    [commit] = build_params(commits: [[author_username: "foo", committer_username: nil]]) |> IngestCommits.from_params()
    assert commit.usernames == ["foo"]

    [commit] = build_params(commits: [[author_username: nil, committer_username: "bar"]]) |> IngestCommits.from_params()
    assert commit.usernames == ["bar"]

    [commit] = build_params(commits: [[author_username: "foo", committer_username: "foo"]]) |> IngestCommits.from_params()
    assert commit.usernames == ["foo"]
  end

  test "assigns usernames from author and committer email 'plus addressing'" do
    [commit] =
      build_params(
        commits: [
          [
            author_username: nil,
            author_email: "devs+foo+bar@example.com",
            committer_username: nil,
            committer_email: "devs+baz+boink@auctionet.com"
          ]
        ]
      )
      |> IngestCommits.from_params()

    assert commit.usernames == ["foo", "bar", "baz", "boink"]
  end

  test "assigns usernames from co-authors in commit trailers" do
    [commit] =
      build_params(
        commits: [
          [
            author_username: "baz",
            committer_username: "baz",
            message: "This is a commit \n\nCo-authored-by: Foo Bar <123+foo.bar@users.noreply.github.com>"
          ]
        ]
      )
      |> IngestCommits.from_params()

    assert commit.usernames == ["baz", "foo.bar"]
  end

  test "can mix usernames and 'plus addressing'" do
    [commit] =
      build_params(
        commits: [
          [
            author_username: nil,
            author_email: "devs+foo+bar@example.com",
            committer_username: "baz"
          ]
        ]
      )
      |> IngestCommits.from_params()

    assert commit.usernames == ["foo", "bar", "baz"]
  end

  test "skips the 'web-flow' committer" do
    [commit] =
      build_params(
        commits: [
          [
            author_username: "foobar",
            committer_username: "web-flow"
          ]
        ]
      )
      |> IngestCommits.from_params()

    assert commit.usernames == ["foobar"]
  end

  test "silently skips any commits already present" do
    Factory.insert!(:commit, sha: "abc123")

    build_params(
      commits: [
        [sha: "abc123"],
        [sha: "def456"]
      ]
    )
    |> IngestCommits.from_params()

    assert Repo.aggregate(from(Commit, where: [sha: "abc123"]), :count) == 1
    assert Repo.aggregate(from(Commit, where: [sha: "def456"]), :count) == 1
  end

  # Private

  defp build_params(opts) do
    branch = Keyword.get(opts, :branch, "master")
    commits = Keyword.get(opts, :commits, [[]])

    %{
      "ref" => "refs/heads/#{branch}",
      "repository" => %{
        "master_branch" => "master",
        "name" => "myrepo",
        "owner" => %{
          "name" => "acme"
        }
      },
      "commits" =>
        commits
        |> Enum.map(fn opts ->
          sha = Keyword.get(opts, :sha, Faker.sha())
          author_username = Keyword.get(opts, :author_username, "foobarson")
          committer_username = Keyword.get(opts, :committer_username, "foobarson")
          author_email = Keyword.get(opts, :author_email, "foo@example.com")
          committer_email = Keyword.get(opts, :committer_email, "foo@example.com")
          message = Keyword.get(opts, :message, "Commit")

          author = %{
            "email" => author_email,
            "name" => "Foo Barson"
          }

          author = if author_username, do: Map.merge(author, %{"username" => author_username}), else: author

          committer = %{
            "email" => committer_email,
            "name" => "Foo Barson"
          }

          committer = if committer_username, do: Map.merge(committer, %{"username" => committer_username}), else: committer

          %{
            "author" => author,
            "committer" => committer,
            "id" => sha,
            "url" => "http://example.com/1",
            "message" => message,
            "timestamp" => "2016-01-25T08:41:25+01:00"
          }
        end)
    }
  end
end
