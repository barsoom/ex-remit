defmodule RemitWeb.StatsControllerTest do
  use RemitWeb.ConnCase
  alias Remit.Factory

  test "it gives some stats" do
    now = DateTime.utc_now()

    # Too old to count in reviewer stats.
    secs_for_11_days = 60 * 60 * 24 * 11
    Factory.insert!(:commit, reviewed_at: now, updated_at: DateTime.add(now, -secs_for_11_days), reviewed_by_username: "baz")

    # Ignored because it's unlisted.
    Factory.insert!(:commit, reviewed_at: nil, inserted_at: DateTime.add(now, -200), unlisted: true)

    Factory.insert!(:commit, reviewed_at: nil, inserted_at: DateTime.add(now, -100))
    Factory.insert!(:commit, reviewed_at: nil, inserted_at: DateTime.add(now, -50))
    Factory.insert!(:commit, reviewed_at: now, reviewed_by_username: "foo")
    Factory.insert!(:commit, reviewed_at: now, reviewed_by_username: "FOO")
    Factory.insert!(:commit, reviewed_at: now, reviewed_by_username: "bar")

    # Ignored because it's unlisted.
    Factory.insert!(:commit, reviewed_at: now, reviewed_by_username: "baz", unlisted: true)

    conn = get_stats()

    assert json_response(conn, 200) == %{
      "unreviewed_count" => 2,
      "oldest_unreviewed_in_seconds" => 100,
      "recent_commits_count" => 5,
      "recent_reviews" => %{
        "bar" => 1,
        "foo" => 2,  # Normalised to lowercase.
      },
    }
  end

  test "'unreviewed_count' and 'oldest_unreviewed_in_seconds' only looks at the latest (by ID) so-and-so many commits" do
    now = DateTime.utc_now()

    Factory.insert!(:commit, reviewed_at: nil, inserted_at: DateTime.add(now, -100))
    Factory.insert!(:commit, reviewed_at: nil, inserted_at: DateTime.add(now, -75))
    Factory.insert!(:commit, reviewed_at: nil, inserted_at: DateTime.add(now, -50))

    conn = get_stats(max_commits: 2)

    assert %{
      "unreviewed_count" => 2,
      "oldest_unreviewed_in_seconds" => 75,
    } = json_response(conn, 200)
  end

  test "it gives sensible stats when there's no data" do
    conn = get_stats()

    assert json_response(conn, 200) == %{
      "unreviewed_count" => 0,
      "oldest_unreviewed_in_seconds" => nil,
      "recent_commits_count" => 0,
      "recent_reviews" => %{},
    }
  end

  defp get_stats(opts \\ []) do
    max_commits = Keyword.get(opts, :max_commits)

    build_conn()
    |> get("/api/stats?auth_key=test_auth_key#{if max_commits, do: "&max_commits_for_tests=#{max_commits}"}")
  end
end
