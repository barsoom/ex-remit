defmodule RemitWeb.CommitsLiveTest do
  use RemitWeb.ConnCase
  import Phoenix.LiveViewTest

  test "says hello", %{conn: conn} do
    # We haven't yet set our name.
    conn = get(conn, "/?auth_key=test_auth_key")
    assert html_response(conn, 200) =~ "Hello!"

    {:ok, live_view, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "Hello!"
    assert render(live_view) =~ "Hello!"
  end
end
