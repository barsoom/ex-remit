defmodule RemitWeb.StatsControllerTest do
  use RemitWeb.ConnCase
  alias Remit.Factory

  test "it gives some stats" do
    now = DateTime.utc_now()

    # Too old to count in reviewer stats.
    secs_for_11_days = 60 * 60 * 24 * 11
    Factory.insert!(:commit, reviewed_at: now, updated_at: DateTime.add(now, -secs_for_11_days), reviewed_by_username: "baz")

    Factory.insert!(:commit, reviewed_at: nil, inserted_at: DateTime.add(now, -100))
    Factory.insert!(:commit, reviewed_at: nil, inserted_at: DateTime.add(now, -50))
    Factory.insert!(:commit, reviewed_at: now, reviewed_by_username: "foo")
    Factory.insert!(:commit, reviewed_at: now, reviewed_by_username: "FOO")
    Factory.insert!(:commit, reviewed_at: now, reviewed_by_username: "bar")

    conn = get_stats()

    assert json_response(conn, 200) == %{
      "unreviewed_count" => 2,
      "oldest_unreviewed_in_seconds" => 100,
      "recent_commits_count" => 5,
      "recent_reviews" => [
        ["bar", 1],
        ["foo", 2],  # Normalised to lowercase.
      ],
    }
  end

  test "it gives sensible stats when there's no data" do
    conn = get_stats()

    assert json_response(conn, 200) == %{
      "unreviewed_count" => 0,
      "oldest_unreviewed_in_seconds" => nil,
      "recent_commits_count" => 0,
      "recent_reviews" => [],
    }
  end

  defp get_stats do
    build_conn()
    |> get("/api/stats?auth_key=test_auth_key")
  end
end
