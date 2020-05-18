defmodule RemitWeb.CommitsLiveTest do
  use RemitWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Remit.{Repo,Settings}

  test "renders name from per-session settings", %{conn: conn} do
    conn = get(conn, "/")
    session_id = conn |> get_session(:session_id)

    # We haven't yet set our name.
    assert html_response(conn, 200) =~ "Hello, stranger"

    Repo.insert! %Settings{
      session_id: session_id,
      email: "user@example.com",
      name: "Banani",
    }

    {:ok, live_view, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "Hello, Banani"
    assert render(live_view) =~ "Hello, Banani"
  end
end
