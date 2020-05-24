defmodule RemitWeb.GithubWebhookControllerTest do
  use RemitWeb.ConnCase
  import Ecto.Query
  alias Remit.{Repo,Commit}

  describe "ping event" do
    test "pongs back" do
      conn =
        build_conn()
        |> put_req_header("x-github-event", "ping")
        |> post("/webhooks/github?auth_key=test_webhook_key", %{zen: "Yo.", hook_id: 123})

      assert response(conn, 200) == "pong"
    end
  end

  describe "push event" do
    test "creates commits and broadcasts them" do
      json_payload = File.read!("test/fixtures/push_payload.json")
      payload = Jason.decode!(json_payload)

      # TODO: Test broadcast.

      conn =
        build_conn()
        |> put_req_header("x-github-event", "push")
        |> post("/webhooks/github?auth_key=test_webhook_key", payload)

      assert response(conn, 200) == "Thanks!"

      [earlier_commit, later_commit] = Repo.all(from Commit, order_by: [asc: :id])

      assert earlier_commit.message == "Earlier commit"
      assert later_commit.message == "Later commit"
    end

    # TODO: Ignores non-master branches.
  end

  describe "with a bad auth_key" do
    test "returns an error" do
      conn =
        build_conn()
        |> put_req_header("x-github-event", "ping")
        |> post("/webhooks/github?auth_key=bad_webhook_key", %{zen: "Yo.", hook_id: 123})

      assert response(conn, 403) == "Invalid auth_key"
    end
  end
end
