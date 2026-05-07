defmodule Remit.CLITest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO
  alias Remit.CLI

  @moduletag :tmp_dir

  defmodule EchoPlug do
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, _opts) do
      body =
        Jason.encode!(%{
          "method" => conn.method,
          "path" => conn.request_path,
          "query" => conn.query_string,
          "authorization" => get_req_header(conn, "authorization")
        })

      conn |> put_resp_content_type("application/json") |> send_resp(200, body)
    end
  end

  setup %{tmp_dir: tmp_dir} do
    server = start_supervised!({Bandit, plug: EchoPlug, ip: :loopback, port: 0, startup_log: false})
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)
    original_env = Map.new(["XDG_CONFIG_HOME", "REMIT_URL"], &{&1, System.get_env(&1)})

    on_exit(fn ->
      Enum.each(original_env, fn {k, v} -> if v, do: System.put_env(k, v), else: System.delete_env(k) end)
    end)

    System.put_env("XDG_CONFIG_HOME", tmp_dir)
    System.delete_env("REMIT_URL")

    %{server_url: "http://127.0.0.1:#{port}"}
  end

  test "uses the URL saved at login when not overridden", %{server_url: server_url} do
    save_credentials(server_url)

    assert %{"path" => "/api/cli/whoami", "authorization" => ["Bearer token"]} = run(["--json", "whoami"])
  end

  test "--base-url overrides the saved URL for every command", %{server_url: server_url} do
    save_credentials("http://127.0.0.1:1")
    System.put_env("REMIT_URL", "http://127.0.0.1:1")

    assert %{"path" => "/api/cli/whoami"} = run(["--base-url", server_url, "--json", "whoami"])
    assert %{"path" => "/api/cli/stats"} = run(["--base-url", server_url, "--json", "stats"])

    assert %{"path" => "/api/cli/commits", "query" => "limit=10"} =
             run(["--json", "--base-url", server_url, "commits", "list", "--limit", "10"])

    assert %{"method" => "POST", "path" => "/api/cli/commits/42/review"} =
             run(["--base-url", server_url, "--json", "commits", "review", "42"])

    assert %{"path" => "/api/cli/comments", "query" => "resolved_filter=resolved&user_filter=all"} =
             run(["--base-url", server_url, "--json", "comments", "list", "--is", "resolved", "--role", "all"])

    assert %{"method" => "POST", "path" => "/api/cli/comments/7/resolve"} =
             run(["--base-url", server_url, "--json", "comments", "resolve", "7"])
  end

  test "REMIT_URL overrides the saved URL", %{server_url: server_url} do
    save_credentials("http://127.0.0.1:1")
    System.put_env("REMIT_URL", server_url)

    assert %{"path" => "/api/cli/whoami"} = run(["--json", "whoami"])
  end

  defp run(argv), do: capture_io(fn -> CLI.main(argv) end) |> Jason.decode!()

  defp save_credentials(base_url) do
    Remit.CLI.Client.save_credentials!(%{
      "access_token" => "token",
      "refresh_token" => "refresh",
      "expires_at" => System.system_time(:second) + 3600,
      "base_url" => base_url
    })
  end
end
