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
    test "works" do
      json_payload = File.read!("test/fixtures/push_payload.json")
      payload = Jason.decode!(json_payload)

      conn =
        build_conn()
        |> put_req_header("x-github-event", "push")
        |> post("/webhooks/github?auth_key=test_webhook_key", payload)

      assert response(conn, 200) == "Thanks!"

      commit = Repo.one!(from Commit, limit: 1)
      assert commit.sha == "c5472c5276f564621afe4b56b14f50e7c298dff9"
      assert commit.message == "This is a commit message"
    end
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
