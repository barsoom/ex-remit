defmodule RemitWeb.StatsControllerTest do
  use RemitWeb.ConnCase
  alias Remit.Factory

  test "it gives some stats" do
    now = DateTime.utc_now()
    Factory.insert!(:commit, reviewed_at: nil, inserted_at: DateTime.add(now, -100))
    Factory.insert!(:commit, reviewed_at: nil, inserted_at: DateTime.add(now, -50))
    Factory.insert!(:commit, reviewed_at: DateTime.utc_now())

    conn = get_stats()

    assert json_response(conn, 200) == %{
      "unreviewed_count" => 2,
      "oldest_unreviewed_in_seconds" => 100,
    }
  end

  test "it gives sensible stats when there's no data" do
    conn = get_stats()

    assert json_response(conn, 200) == %{
      "unreviewed_count" => 0,
      "oldest_unreviewed_in_seconds" => nil,
    }
  end

  defp get_stats do
    build_conn()
    |> get("/api/stats?auth_key=test_auth_key")
  end
end
