defmodule RemitWeb.CommitsLiveTest do
  use RemitWeb.ConnCase
  import Phoenix.LiveViewTest
  alias RemitWeb.CommitsLive
  alias Remit.Factory

  @github_user %Remit.Github.User{login: "dwight"}

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

  describe "filters" do
    setup %{conn: conn} do
      conn = conn |> Plug.Test.init_test_session(%{"github_user" => @github_user})
      conn = get(conn, "/commits?auth_key=test_auth_key")

      %{conn: conn}
    end

    test "shows commits you've made", %{conn: conn} do
      commit_not_by_me =
        Factory.insert!(:commit,
          usernames: ["michael"],
          message: "some message by michael"
        )

      commit_by_me =
        Factory.insert!(:commit,
          usernames: ["dwight"],
          message: "some message by dwight"
        )

      {:ok, view, _html} = live(conn, "/commits")

      children = live_children(view)
      commits_lv = Enum.find(children, &(&1.id == "commits"))

      assert view |> has_element?("p", commit_not_by_me.message)
      assert view |> has_element?("p", commit_by_me.message)

      # filter by me
      assert commits_lv |> element("a", "Me") |> render_click()

      refute view |> has_element?("p", commit_not_by_me.message)
      assert view |> has_element?("p", commit_by_me.message)
    end
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
      assert socket.assigns.projects_of_team == "all"
    end
  end
end
