defmodule RemitWeb.MCPControllerTest do
  use RemitWeb.ConnCase

  alias Remit.{Factory, Repo, Commits}

  describe "auth and discovery" do
    test "401 without bearer, with WWW-Authenticate hint", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/mcp", Jason.encode!(%{}))

      assert conn.status == 401

      [auth_header] = Plug.Conn.get_resp_header(conn, "www-authenticate")
      assert auth_header =~ "Bearer realm=\"mcp\""
      assert auth_header =~ "resource_metadata="
      assert auth_header =~ "/.well-known/oauth-protected-resource/mcp"
    end

    test "401 with tampered bearer", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer not.a.token")
        |> post("/mcp", Jason.encode!(%{}))

      assert conn.status == 401
    end

    test "403 with disallowed Origin", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> bearer()
        |> put_req_header("origin", "https://evil.example.com")
        |> post("/mcp", Jason.encode!(%{}))

      assert conn.status == 403
    end

    test "400 with unsupported MCP-Protocol-Version", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> bearer()
        |> put_req_header("mcp-protocol-version", "1999-01-01")
        |> post("/mcp", Jason.encode!(%{}))

      assert conn.status == 400
    end

    test "200 with supported MCP-Protocol-Version", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> bearer()
        |> put_req_header("mcp-protocol-version", "2025-11-25")
        |> post(
          "/mcp",
          Jason.encode!(%{"jsonrpc" => "2.0", "id" => 1, "method" => "tools/list"})
        )

      assert conn.status == 200
    end
  end

  describe "tools/list" do
    test "lists 9 tools, JSON round-trips", %{conn: conn} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> bearer()
        |> post(
          "/mcp",
          Jason.encode!(%{"jsonrpc" => "2.0", "id" => 1, "method" => "tools/list"})
        )
        |> json_response(200)

      assert length(response["result"]["tools"]) == 9

      # Re-encode through Jason to assert no surprise non-encodable shapes.
      reencoded = Jason.encode!(response) |> Jason.decode!()
      assert reencoded["result"]["tools"] |> length() == 9
    end
  end

  describe "tools/call" do
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

    test "mark_reviewed happy path", %{conn: conn} do
      commit = Factory.insert!(:commit, repo: "ownerless")

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> bearer()
        |> post(
          "/mcp",
          Jason.encode!(%{
            "jsonrpc" => "2.0",
            "id" => 7,
            "method" => "tools/call",
            "params" => %{"name" => "mark_reviewed", "arguments" => %{"id" => commit.id}}
          })
        )
        |> json_response(200)

      assert response["result"]["isError"] == false
      assert response["result"]["structuredContent"]["reviewed_by_username"] == "octocat"

      assert_receive {:subscriber_got, {:changed_commit, _}}
    end

    test "list_commits wraps the array in `items` for structuredContent", %{conn: conn} do
      Factory.insert!(:commit)

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> bearer()
        |> post(
          "/mcp",
          Jason.encode!(%{
            "jsonrpc" => "2.0",
            "id" => 11,
            "method" => "tools/call",
            "params" => %{"name" => "list_commits", "arguments" => %{}}
          })
        )
        |> json_response(200)

      assert response["result"]["isError"] == false
      # MCP spec requires structuredContent to be an object, not a bare array.
      structured = response["result"]["structuredContent"]
      assert is_map(structured)
      assert is_list(structured["items"])
    end

    test "stale integer commit id returns isError with bad-request text", %{conn: conn} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> bearer()
        |> post(
          "/mcp",
          Jason.encode!(%{
            "jsonrpc" => "2.0",
            "id" => 8,
            "method" => "tools/call",
            "params" => %{
              "name" => "mark_reviewed",
              "arguments" => %{"id" => 999_999_999}
            }
          })
        )
        |> json_response(200)

      assert response["result"]["isError"] == true
      assert response["result"]["content"] |> hd() |> Map.get("text") =~ "no commit found"
    end

    test "scope error returns isError true (not 401/403)", %{conn: conn} do
      commit = Factory.insert!(:commit, repo: "ownerless")

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> bearer(["remit:read"])
        |> post(
          "/mcp",
          Jason.encode!(%{
            "jsonrpc" => "2.0",
            "id" => 9,
            "method" => "tools/call",
            "params" => %{"name" => "mark_reviewed", "arguments" => %{"id" => commit.id}}
          })
        )
        |> json_response(200)

      assert response["result"]["isError"] == true
      assert response["result"]["content"] |> hd() |> Map.get("text") =~ "scope"

      assert Repo.get!(Remit.Commit, commit.id).reviewed_at == nil
    end
  end

  describe "batch via _json" do
    test "responds with an array", %{conn: conn} do
      payload = [
        %{"jsonrpc" => "2.0", "id" => 1, "method" => "tools/list"},
        %{"jsonrpc" => "2.0", "id" => 2, "method" => "tools/list"}
      ]

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> bearer()
        |> post("/mcp", Jason.encode!(payload))
        |> json_response(200)

      assert is_list(response)
      assert length(response) == 2
    end
  end

  describe "GET /mcp" do
    test "returns 405", %{conn: conn} do
      conn =
        conn
        |> bearer()
        |> get("/mcp")

      assert conn.status == 405
    end
  end
end
