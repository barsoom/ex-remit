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

  describe "scroll pagination" do
    test "works", %{conn: conn, socket: socket} do
      commits =
        Enum.map(0..5, fn i ->
          %{Factory.build(:commit) | message: "Commit #{i}"}
          |> Remit.Repo.insert()
        end)
    end
  end

  describe "unit tests" do
    setup do
      create_socket()
    end

    test "assigns the correct defaults", %{socket: socket} do
      session = %{"github_user" => %Remit.Github.User{login: "dwight"}}
      socket = CommitsLive.assign_defaults(socket, session)

      assert socket.assigns.username == "dwight"
      assert socket.assigns.your_last_selected_commit_id == nil
      assert socket.assigns.projects_of_team == "all"
    end
  end
end
