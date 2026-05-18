defmodule RemitWeb.CommitsLiveTest do
  use RemitWeb.ConnCase
  import Phoenix.LiveViewTest
  alias RemitWeb.CommitsLive
  alias Remit.Factory

  @github_user %Remit.Github.User{login: "dwight"}

  defp create_socket do
    %{socket: %Phoenix.LiveView.Socket{}}
  end

  defp filter_by_me(view) do
    commits_lv = view |> live_children() |> Enum.find(&(&1.id == "commits"))
    assert commits_lv |> element("a", "Me") |> render_click()
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

    test "shows commits you've made, including ones arriving via live update", %{conn: conn} do
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

      assert view |> has_element?("p", commit_not_by_me.message)
      assert view |> has_element?("p", commit_by_me.message)

      view |> filter_by_me()

      refute view |> has_element?("p", commit_not_by_me.message)
      assert view |> has_element?("p", commit_by_me.message)

      # Filter also applies to commits arriving via live update.
      new_commit_by_me = Factory.build(:commit, id: 1, usernames: ["dwight"], message: "new commit by dwight")
      new_commit_by_other = Factory.build(:commit, id: 2, usernames: ["michael"], message: "new commit by michael")
      commits_lv = view |> live_children() |> Enum.find(&(&1.id == "commits"))
      send(commits_lv.pid, {:new_commits, [new_commit_by_me, new_commit_by_other]})

      assert render(commits_lv) =~ new_commit_by_me.message
      refute render(commits_lv) =~ new_commit_by_other.message
    end

    test "hides 'nothing left for you to review' when filtered to your own commits", %{conn: conn} do
      Factory.insert!(:commit, usernames: ["dwight"], message: "by me")

      {:ok, view, _html} = live(conn, "/commits")

      assert view |> has_element?("p", "Nothing left for you to review!")

      view |> filter_by_me()
      refute view |> has_element?("p", "Nothing left for you to review!")
    end
  end

  describe "self-review block" do
    setup %{conn: conn} do
      conn = conn |> Plug.Test.init_test_session(%{"github_user" => @github_user})
      conn = get(conn, "/commits?auth_key=test_auth_key")
      %{conn: conn}
    end

    test "start_review on a self-authored commit leaves the row untouched", %{conn: conn} do
      commit = Factory.insert!(:commit, usernames: ["dwight"], repo: "ownerless")

      {:ok, view, _html} = live(conn, "/commits")
      commits_lv = view |> live_children() |> Enum.find(&(&1.id == "commits"))

      render_hook(commits_lv, "start_review", %{"id" => commit.id})

      reloaded = Remit.Repo.get!(Remit.Commit, commit.id)
      assert reloaded.review_started_at == nil
      assert reloaded.review_started_by_username == nil
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
