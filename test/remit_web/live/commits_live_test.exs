defmodule RemitWeb.CommitsLiveTest do
  use RemitWeb.ConnCase
  import Phoenix.LiveViewTest
  alias RemitWeb.CommitsLive
  alias Remit.Factory

  defp create_socket do
    %{socket: %Phoenix.LiveView.Socket{}}
  end

  test "says hello", %{conn: conn} do
    # We haven't yet set our name.
    conn = get(conn, "/commits?auth_key=test_auth_key")
    assert html_response(conn, 200) =~ "Nothing yet!"

    {:ok, live_view, disconnected_html} = live(conn, "/commits")
    assert disconnected_html =~ "Nothing yet!"
    assert render(live_view) =~ "Nothing yet!"
  end

  describe "unit tests" do
    setup do
      create_socket()
    end

    test "assigns the correct defaults", %{socket: socket} do
      session = %{"github_user" => %Remit.Github.User{login: "dwight"}}
      Enum.map(0..5, fn _ -> Factory.build(:commit) end)
      socket = CommitsLive.assign_defaults(socket, session)

      assert socket.assigns.username == "dwight"
      assert socket.assigns.your_last_selected_commit_id == nil
      assert socket.assigns.team == "all"
    end
  end
end
