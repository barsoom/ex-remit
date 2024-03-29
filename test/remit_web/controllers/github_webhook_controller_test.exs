defmodule RemitWeb.GithubWebhookControllerTest do
  use RemitWeb.ConnCase
  import Ecto.Query
  alias Remit.{Repo, Commits, Commit, Comments, Comment, CommentNotification, Factory}

  @earlier_commit_sha "c5472c5276f564621afe4b56b14f50e7c298dff9"

  describe "'ping' event" do
    test "pongs back" do
      conn = build_ping_payload() |> post_payload("ping")

      assert response(conn, 200) == "pong"
    end
  end

  describe "'push' event (commits)" do
    setup do
      parent = self()

      spawn_link(fn ->
        Commits.subscribe()

        receive do
          msg -> send(parent, {:subscriber_got, msg})
        end
      end)

      :ok
    end

    test "creates commits and broadcasts them" do
      conn = build_push_payload(branch: "master") |> post_payload("push")

      assert response(conn, 200) == "Thanks!"

      [earlier_commit, later_commit] = Repo.all(from Commit, order_by: [asc: :id])
      assert earlier_commit.message == "Earlier commit"
      assert later_commit.message == "Later commit"

      # Broadcasts to subscribers.
      assert_receive {:subscriber_got,
                      {:new_commits,
                       [
                         %Commit{message: "Later commit"},
                         %Commit{message: "Earlier commit"}
                       ]}}
    end

    test "silently skips any commits already present" do
      Factory.insert!(:commit, sha: @earlier_commit_sha, message: "Pre-existing commit")

      conn = build_push_payload(branch: "master") |> post_payload("push")

      assert response(conn, 200) == "Thanks!"

      [earlier_commit, later_commit] = Repo.all(from Commit, order_by: [asc: :id])
      assert earlier_commit.message == "Pre-existing commit"
      assert later_commit.message == "Later commit"

      # Broadcasts to subscribers.
      assert_receive {:subscriber_got,
                      {:new_commits,
                       [
                         %Commit{message: "Later commit"}
                       ]}}
    end

    test "gracefully does nothing on a non-master branch" do
      conn = build_push_payload(branch: "blaster") |> post_payload("push")

      assert response(conn, 200) == "Thanks!"
      assert Repo.aggregate(Commit, :count) == 0

      # Nothing is broadcast.
      refute_receive {:subscriber_got, _}
    end
  end

  describe "'commit_comment' event" do
    test "creates a comment and notifications, and broadcasts them" do
      parent = self()

      spawn_link(fn ->
        Comments.subscribe()

        receive do
          msg -> send(parent, {:subscriber_got, msg})
        end
      end)

      commit = Factory.insert!(:commit, sha: "abc123", usernames: ["riffraff", "magenta"])
      Factory.insert!(:comment, commit: commit, commenter_username: "charles")

      conn =
        build_comment_payload(sha: "abc123", username: "ada")
        |> post_payload("commit_comment")

      # Responds politely.
      assert response(conn, 200) == "Thanks!"

      # Creates a comment.
      comment = Repo.one(from Comment, limit: 1, order_by: [desc: :id])
      assert comment.body == "Hello world!"

      # Broadcasts to subscribers.
      assert_receive {:subscriber_got, :comments_changed}

      # Notifies committer(s).
      assert Repo.exists?(from CommentNotification, where: [username: "riffraff"])
      assert Repo.exists?(from CommentNotification, where: [username: "magenta"])

      # Notifies previous commenter.
      assert Repo.exists?(from CommentNotification, where: [username: "charles"])

      # Does not notify commenter.
      refute Repo.exists?(from CommentNotification, where: [username: "ada"])
    end

    test "silently skips a comment already present" do
      parent = self()

      spawn_link(fn ->
        Comments.subscribe()

        receive do
          msg -> send(parent, {:subscriber_got, msg})
        end
      end)

      commit = Factory.insert!(:commit)
      Factory.insert!(:comment, commit: commit, github_id: 123, body: "Pre-existing comment")

      conn =
        build_comment_payload(sha: commit.sha, github_id: 123, body: "New comment")
        |> post_payload("commit_comment")

      assert response(conn, 200) == "Thanks!"

      assert [%Comment{body: "Pre-existing comment"}] = Repo.all(Comment)

      assert Repo.aggregate(Comment, :count) == 1
      assert Repo.aggregate(CommentNotification, :count) == 0

      refute_receive {:subscriber_got, :comments_changed}
    end
  end

  describe "with a bad auth_key" do
    test "returns an error" do
      conn = build_ping_payload() |> post_payload("ping", auth_key: "bad_key")

      assert response(conn, 403) == "Invalid auth_key"
    end
  end

  # Private

  defp post_payload(payload, event, opts \\ []) do
    auth_key = Keyword.get(opts, :auth_key, "test_webhook_key")

    build_conn()
    |> put_req_header("x-github-event", event)
    |> post("/webhooks/github?auth_key=#{auth_key}", payload)
  end

  defp build_ping_payload, do: %{zen: "Yo.", hook_id: 123}

  defp build_push_payload(opts) do
    branch = Keyword.get(opts, :branch, "master")

    # This is a subset of the actual payload.
    # Reference: https://developer.github.com/webhooks/event-payloads/#push
    %{
      ref: "refs/heads/#{branch}",
      repository: %{
        master_branch: "master",
        name: "myrepo",
        owner: %{
          name: "acme"
        }
      },
      commits: [
        %{
          author: %{
            email: "foo@example.com",
            username: "foobarson"
          },
          committer: %{
            email: "foo@example.com",
            username: "foobarson"
          },
          id: @earlier_commit_sha,
          url: "http://example.com/1",
          message: "Earlier commit",
          timestamp: "2016-01-25T08:41:25+01:00"
        },
        %{
          author: %{
            email: "foo@example.com",
            username: "foobar"
          },
          committer: %{
            email: "foo+one+two@example.com"
          },
          id: "d5472c5276f564621afe4b56b14f50e7c298dff9",
          url: "http://example.com/2",
          message: "Later commit",
          timestamp: "2016-01-25T08:41:26+01:00"
        }
      ]
    }
  end

  defp build_comment_payload(opts) do
    id = Keyword.get_lazy(opts, :github_id, &Faker.number/0)
    sha = Keyword.get_lazy(opts, :sha, &Faker.sha/0)
    body = Keyword.get(opts, :body, "Hello world!")
    username = Keyword.get(opts, :username, "ada")

    # This is a subset of the actual payload.
    # Reference: https://developer.github.com/webhooks/event-payloads/#commit_comment
    %{
      action: "created",
      comment: %{
        id: id,
        user: %{
          login: username
        },
        commit_id: sha,
        position: nil,
        path: nil,
        created_at: "2016-01-25T08:41:25+01:00",
        body: body
      },
      repository: %{
        name: "footguns",
        owner: %{login: "acme"}
      }
    }
  end
end
