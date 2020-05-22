defmodule RemitWeb.CommitsLiveTest do
  use RemitWeb.ConnCase
  import Phoenix.LiveViewTest

  test "says hello", %{conn: conn} do
    # We haven't yet set our name.
    assert html_response(conn, 200) =~ "Hello, stranger"

    {:ok, live_view, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "Hello, stranger"
    assert render(live_view) =~ "Hello, stranger"
  end
end
