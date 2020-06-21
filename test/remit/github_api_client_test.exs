defmodule Remit.GitHubAPIClientTest do
  use ExUnit.Case
  alias Remit.{GitHubAPIClient, Commit}

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

    test "ignores an empty actor or committer" do
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
end
