defmodule Remit.GitHubAPIClientTest do
  use ExUnit.Case
  alias Remit.{GitHubAPIClient, Commit, Comment}

  describe "fetch_commit" do
    test "builds a commit" do
      mock_response("/repos/acme/footguns/commits/abc123", %{
        "sha" => "abc123",
        "html_url" => "https://example.com/abc123",
        "commit" => %{
          "message" => "My commit.",
          "author" => %{
            "email" => "foo+user1+user2@example.com",
          },
          "committer" => %{
            "email" => "foo+user2+user3@example.com",  # Duplicate user2.
            "date" => "2016-01-25T08:41:25+01:00",
          },
        },
        "author" => %{"login" => "user4"},
        "committer" => %{"login" => "user5"},
      })

      actual = GitHubAPIClient.fetch_commit("acme", "footguns", "abc123")

      assert %Commit{
        sha: "abc123",
        message: "My commit.",
        url: "https://example.com/abc123",
        committed_at: ~U[2016-01-25 07:41:25.000000Z],
        usernames: ["user1", "user2", "user3", "user4", "user5"],
      } = actual
    end

    test "ignores an empty author or committer" do
      mock_response("/repos/acme/footguns/commits/abc123", %{
        "sha" => "abc123",
        "html_url" => "https://example.com/abc123",
        "commit" => %{
          "message" => "My commit.",
          "author" => %{
            "email" => "foo@example.com",
          },
          "committer" => %{
            "email" => "foo@example.com",
            "date" => "2016-01-25T08:41:25+01:00",
          },
        },
        "author" => nil,
        "committer" => %{"login" => "user"},
      })

      actual = GitHubAPIClient.fetch_commit("acme", "footguns", "abc123")

      assert %Commit{usernames: ["user"]} = actual
    end
  end

  describe "fetch_comments_on_commit" do
    test "builds an array of comments" do
      mock_response("/repos/acme/footguns/commits/abc123/comments", [
        %{
          "id" => 123,
          "commit_id" => "abc123",
          "body" => "Hello world!",
          "created_at" => "2016-01-25T08:41:25+01:00",
          "user" => %{
            "login" => "user1",
          },
          "path" => "foo.rb",
          "position" => 456,
        },
      ])

      commit = %Commit{owner: "acme", repo: "footguns", sha: "abc123"}
      actual = GitHubAPIClient.fetch_comments_on_commit(commit)

      assert [
        %Comment{
          github_id: 123,
          commit_sha: "abc123",
          body: "Hello world!",
          commented_at: ~U[2016-01-25 07:41:25.000000Z],
          commenter_username: "user1",
          path: "foo.rb",
          position: 456,
        },
      ] = actual
    end
  end

  defp mock_response(path, response) do
    import Tesla.Mock

    url = "https://api.github.com#{path}"

    mock(fn
      %{
        method: :get,
        url: ^url,
        headers: [{"authorization", "token test_github_api_token"}],
      } -> json(response)
    end)
  end
end
