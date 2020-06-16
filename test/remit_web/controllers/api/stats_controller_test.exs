defmodule RemitWeb.StatsControllerTest do
  use RemitWeb.ConnCase
  alias Remit.Factory

  test "it gives some stats" do
    Factory.insert!(:commit, reviewed_at: nil)
    Factory.insert!(:commit, reviewed_at: nil)
    Factory.insert!(:commit, reviewed_at: DateTime.utc_now())

    conn =
      build_conn()
      |> get("/api/stats?auth_key=test_auth_key")

    assert json_response(conn, 200) == %{
      "unreviewed_count" => 2,
    }
  end
end
