defmodule RemitWeb.GithubWebhookControllerTest do
  use RemitWeb.ConnCase
  import Ecto.Query
  alias Remit.{Repo, Commit}

  describe "ping event" do
    test "pongs back" do
      conn = build_ping_payload() |> post_payload("ping")

      assert response(conn, 200) == "pong"
    end
  end

  describe "push event" do
    test "creates commits and broadcasts them" do
      conn = build_push_payload(branch: "master") |> post_payload("push")

      # TODO: Test broadcast.

      assert response(conn, 200) == "Thanks!"

      [earlier_commit, later_commit] = Repo.all(from Commit, order_by: [asc: :id])
      assert earlier_commit.message == "Earlier commit"
      assert later_commit.message == "Later commit"
    end

    test "gracefully does nothing on a non-master branch" do
      conn = build_push_payload(branch: "blaster") |> post_payload("push")

      # TODO: Test (lack of) broadcast.
      assert response(conn, 200) == "Thanks!"
      assert Repo.aggregate(Commit, :count) == 0
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
        name: Faker.repo(),
        owner: %{
          name: "acme",
        },
      },
      commits: [
        %{
          author: %{
            email: "foo@example.com",
            name: "Foo Barson",
          },
          id: "c5472c5276f564621afe4b56b14f50e7c298dff9",
          message: "Earlier commit",
          timestamp: "2016-01-25T08:41:25+01:00",
        },
        %{
          author: %{
            email: "foo@example.com",
            name: "Foo Barson",
          },
          id: "d5472c5276f564621afe4b56b14f50e7c298dff9",
          message: "Later commit",
          timestamp: "2016-01-25T08:41:26+01:00",
        },
      ],
    }
  end
end
