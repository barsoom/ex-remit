defmodule RemitWeb.CLI.ToolControllerTest do
  use RemitWeb.ConnCase

  alias Remit.{Factory, Repo, Commits, Comments, Commit}

  test "401 without bearer", %{conn: conn} do
    conn = get(conn, "/api/cli/commits")
    assert conn.status == 401
  end

  test "GET /api/cli/whoami returns username", %{conn: conn} do
    response =
      conn
      |> bearer()
      |> get("/api/cli/whoami")
      |> json_response(200)

    assert response == %{"username" => "octocat"}
  end

  test "GET /api/cli/commits happy path", %{conn: conn} do
    Factory.insert!(:commit)

    response =
      conn
      |> bearer()
      |> get("/api/cli/commits")
      |> json_response(200)

    assert is_list(response)
    refute response == []
  end

  describe "POST /api/cli/commits/:id/review" do
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

    test "happy path + broadcast", %{conn: conn} do
      commit = Factory.insert!(:commit, repo: "ownerless")

      response =
        conn
        |> bearer()
        |> post("/api/cli/commits/#{commit.id}/review")
        |> json_response(200)

      assert response["reviewed_by_username"] == "octocat"
      assert_receive {:subscriber_got, {:changed_commit, %Commit{}}}
    end

    test "403 with read-only token", %{conn: conn} do
      commit = Factory.insert!(:commit, repo: "ownerless", reviewed_at: nil)

      response =
        conn
        |> bearer(["remit:read"])
        |> post("/api/cli/commits/#{commit.id}/review")
        |> json_response(403)

      assert response["error"] == "insufficient_scope"
      assert Repo.get!(Commit, commit.id).reviewed_at == nil
    end

    test "403 with non-team-member on a team-owned project", %{conn: conn} do
      Factory.insert!(:team,
        slug: "alpha",
        projects: ["myproject"],
        review_access: :team,
        usernames: ["alice"]
      )

      commit = Factory.insert!(:commit, repo: "myproject", reviewed_at: nil)

      response =
        conn
        |> bearer(["remit:review"], "outsider")
        |> post("/api/cli/commits/#{commit.id}/review")
        |> json_response(403)

      assert response["error"] == "forbidden"
      assert Repo.get!(Commit, commit.id).reviewed_at == nil
    end

    test "403 for the caller's own commit", %{conn: conn} do
      commit = Factory.insert!(:commit, repo: "ownerless", usernames: ["octocat"], reviewed_at: nil)

      response =
        conn
        |> bearer()
        |> post("/api/cli/commits/#{commit.id}/review")
        |> json_response(403)

      assert response["error"] == "forbidden"
      assert Repo.get!(Commit, commit.id).reviewed_at == nil
    end
  end

  describe "GET /api/cli/teams" do
    test "returns teams filtered by member", %{conn: conn} do
      Factory.insert!(:team, slug: "alpha", usernames: ["alice"])
      Factory.insert!(:team, slug: "beta", usernames: ["bob"])

      response =
        conn
        |> bearer()
        |> get("/api/cli/teams?member=alice")
        |> json_response(200)

      assert is_list(response)
      assert length(response) == 1
      assert hd(response)["slug"] == "alpha"
    end
  end

  describe "POST /api/cli/comments/:id/resolve" do
    setup do
      parent = self()

      spawn_link(fn ->
        Comments.subscribe()

        receive do
          msg -> send(parent, {:subscriber_got, msg})
        end
      end)

      :ok
    end

    test "happy path + broadcast", %{conn: conn} do
      notification = Factory.insert!(:comment_notification, username: "octocat")

      response =
        conn
        |> bearer()
        |> post("/api/cli/comments/#{notification.id}/resolve")
        |> json_response(200)

      assert response["id"] == notification.id
      assert response["resolved_at"] != nil

      assert_receive {:subscriber_got, :comments_changed}
    end

    test "403 when notification is not addressed to caller", %{conn: conn} do
      notification = Factory.insert!(:comment_notification, username: "someoneelse")

      response =
        conn
        |> bearer()
        |> post("/api/cli/comments/#{notification.id}/resolve")
        |> json_response(403)

      assert response["error"] == "forbidden"
      assert Repo.get!(Remit.CommentNotification, notification.id).resolved_at == nil
    end
  end
end
