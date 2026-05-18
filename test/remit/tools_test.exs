defmodule Remit.ToolsTest do
  use Remit.DataCase, async: false

  alias Remit.{Tools, Commits, Comments, Repo, Commit, Factory}

  @read_ctx %{username: "octocat", scopes: ["remit:read"]}
  @review_ctx %{username: "octocat", scopes: ["remit:review"]}

  describe "list/0" do
    test "returns 9 tools, every entry round-trips through Jason" do
      tools = Tools.list()
      assert length(tools) == 9

      for tool <- tools do
        assert tool.scopes != []
        encoded = Jason.encode!(tool.input_schema)
        assert is_binary(encoded)
        assert Jason.decode!(encoded)["type"] == "object"
      end
    end
  end

  describe "stats" do
    test "matches what StatsController exposes" do
      Factory.insert!(:commit, reviewed_at: nil)

      assert {:ok,
              %{
                "unreviewed_count" => 1,
                "reviewable_count" => 1
              }} = Tools.call("stats", %{}, @read_ctx)
    end
  end

  describe "list_commits" do
    test "happy path with author filter" do
      Factory.insert!(:commit, usernames: ["foo"])
      Factory.insert!(:commit, usernames: ["bar"])

      {:ok, commits} = Tools.call("list_commits", %{"author" => "foo"}, @read_ctx)
      assert length(commits) == 1
      assert hd(commits).usernames == ["foo"]
    end
  end

  describe "list_comments" do
    test "defaults user_filter to for_me" do
      Factory.insert!(:comment_notification, username: "octocat")
      Factory.insert!(:comment_notification, username: "someoneelse")

      {:ok, notifications} = Tools.call("list_comments", %{}, @read_ctx)

      assert length(notifications) == 1
      assert hd(notifications).username == "octocat"
    end
  end

  describe "mark_reviewed" do
    setup do
      parent = self()

      spawn_link(fn ->
        Commits.subscribe()

        receive do
          msg -> send(parent, {:subscriber_got, msg})
        end
      end)

      :ok
    end

    test "happy path" do
      commit = Factory.insert!(:commit, repo: "ownerless")

      assert {:ok, payload} =
               Tools.call("mark_reviewed", %{"id" => commit.id}, @review_ctx)

      assert payload.reviewed_by_username == "octocat"
      assert payload.id == commit.id
      assert payload.short_sha == String.slice(commit.sha, 0, 8)

      assert_receive {:subscriber_got, {:changed_commit, %Commit{}}}
    end

    test "mark_unreviewed broadcasts (since the underlying call doesn't on its own)" do
      commit = Factory.insert!(:commit, repo: "ownerless", reviewed_at: DateTime.utc_now(), reviewed_by_username: "x")

      assert {:ok, _} = Tools.call("mark_unreviewed", %{"id" => commit.id}, @review_ctx)
      assert_receive {:subscriber_got, {:changed_commit, %Commit{}}}
    end
  end

  describe "resolve_comment / unresolve_comment" do
    setup do
      parent = self()

      spawn_link(fn ->
        Comments.subscribe()

        receive do
          msg -> send(parent, {:subscriber_got, msg})
        end
      end)

      :ok
    end

    test "resolve preloads associations and returns full payload" do
      notification = Factory.insert!(:comment_notification, username: "octocat")

      assert {:ok, payload} =
               Tools.call("resolve_comment", %{"id" => notification.id}, @review_ctx)

      assert payload.id == notification.id
      assert payload.comment.id == notification.comment.id
      assert payload.commit.repo == notification.comment.commit.repo

      assert_receive {:subscriber_got, :comments_changed}
    end

    test "unresolve preloads associations and returns full payload" do
      notification =
        Factory.insert!(:comment_notification, username: "octocat", resolved_at: DateTime.utc_now())

      assert {:ok, payload} =
               Tools.call("unresolve_comment", %{"id" => notification.id}, @review_ctx)

      assert payload.id == notification.id
      assert payload.comment.id == notification.comment.id
      assert payload.commit.repo == notification.comment.commit.repo

      assert_receive {:subscriber_got, :comments_changed}
    end

    test "resolve denied when notification is not addressed to caller" do
      notification = Factory.insert!(:comment_notification, username: "someoneelse")

      assert {:error, :forbidden, _} =
               Tools.call("resolve_comment", %{"id" => notification.id}, @review_ctx)

      assert Repo.get!(Remit.CommentNotification, notification.id).resolved_at == nil
    end

    test "unresolve denied when notification is not addressed to caller" do
      notification =
        Factory.insert!(:comment_notification,
          username: "someoneelse",
          resolved_at: DateTime.utc_now()
        )

      assert {:error, :forbidden, _} =
               Tools.call("unresolve_comment", %{"id" => notification.id}, @review_ctx)

      assert Repo.get!(Remit.CommentNotification, notification.id).resolved_at != nil
    end

    test "resolve returns :bad_request when the id refers to no notification" do
      assert {:error, :bad_request, _} =
               Tools.call("resolve_comment", %{"id" => 999_999_999}, @review_ctx)
    end
  end

  describe "scope enforcement" do
    test "list_commits succeeds with read-only scope" do
      Factory.insert!(:commit)
      assert {:ok, _} = Tools.call("list_commits", %{}, @read_ctx)
    end

    test "mark_reviewed with read-only scope returns insufficient_scope and does not mutate" do
      commit = Factory.insert!(:commit, repo: "ownerless", reviewed_at: nil)

      assert {:error, :insufficient_scope, _} =
               Tools.call("mark_reviewed", %{"id" => commit.id}, @read_ctx)

      assert Repo.get!(Commit, commit.id).reviewed_at == nil
    end

    test "every write tool is gated" do
      commit = Factory.insert!(:commit, repo: "ownerless")

      for tool <- ~w(start_review mark_reviewed mark_unreviewed) do
        assert {:error, :insufficient_scope, _} =
                 Tools.call(tool, %{"id" => commit.id}, @read_ctx)
      end

      notification = Factory.insert!(:comment_notification)

      for tool <- ~w(resolve_comment unresolve_comment) do
        assert {:error, :insufficient_scope, _} =
                 Tools.call(tool, %{"id" => notification.id}, @read_ctx)
      end
    end
  end

  describe "per-project authorization gate" do
    test "denies user not on any owning team" do
      Factory.insert!(:team,
        slug: "alpha",
        projects: ["myproject"],
        review_access: :team,
        usernames: ["alice"]
      )

      commit = Factory.insert!(:commit, repo: "myproject", reviewed_at: nil)

      assert {:error, :forbidden, _} =
               Tools.call(
                 "mark_reviewed",
                 %{"id" => commit.id},
                 %{username: "outsider", scopes: ["remit:review"]}
               )

      assert Repo.get!(Commit, commit.id).reviewed_at == nil
    end

    test "permits user when project has no team owners" do
      commit = Factory.insert!(:commit, repo: "ownerless", reviewed_at: nil)

      assert {:ok, _} = Tools.call("mark_reviewed", %{"id" => commit.id}, @review_ctx)
    end
  end

  describe "self-review block" do
    test "mark_reviewed denied when the caller authored the commit" do
      commit = Factory.insert!(:commit, repo: "ownerless", usernames: ["octocat"], reviewed_at: nil)

      assert {:error, :forbidden, _} =
               Tools.call("mark_reviewed", %{"id" => commit.id}, @review_ctx)

      assert Repo.get!(Commit, commit.id).reviewed_at == nil
    end

    test "start_review denied when the caller authored the commit" do
      commit = Factory.insert!(:commit, repo: "ownerless", usernames: ["octocat"], reviewed_at: nil)

      assert {:error, :forbidden, _} =
               Tools.call("start_review", %{"id" => commit.id}, @review_ctx)

      assert Repo.get!(Commit, commit.id).review_started_at == nil
    end

    test "mark_unreviewed denied when the caller authored the commit" do
      commit =
        Factory.insert!(:commit,
          repo: "ownerless",
          usernames: ["octocat"],
          reviewed_at: DateTime.utc_now(),
          reviewed_by_username: "other"
        )

      assert {:error, :forbidden, _} =
               Tools.call("mark_unreviewed", %{"id" => commit.id}, @review_ctx)

      assert Repo.get!(Commit, commit.id).reviewed_at != nil
    end
  end

  describe "list_teams" do
    test "returns all teams when called with no filters" do
      Factory.insert!(:team, slug: "alpha", name: "Alpha", projects: ["p1"], usernames: ["alice"])
      Factory.insert!(:team, slug: "beta", name: "Beta", projects: ["p2"], usernames: ["bob"])

      assert {:ok, teams} = Tools.call("list_teams", %{}, @read_ctx)
      assert Enum.map(teams, & &1.slug) |> Enum.sort() == ["alpha", "beta"]

      [alpha | _] = Enum.filter(teams, &(&1.slug == "alpha"))
      assert alpha.name == "Alpha"
      assert alpha.projects == ["p1"]
      assert alpha.usernames == ["alice"]
      assert alpha.review_access == "public"
    end

    test "filters by slug" do
      Factory.insert!(:team, slug: "alpha")
      Factory.insert!(:team, slug: "beta")

      assert {:ok, [team]} = Tools.call("list_teams", %{"slug" => "alpha"}, @read_ctx)
      assert team.slug == "alpha"
    end

    test "filters by member, case-insensitive" do
      Factory.insert!(:team, slug: "alpha", usernames: ["Alice"])
      Factory.insert!(:team, slug: "beta", usernames: ["bob"])

      assert {:ok, [team]} = Tools.call("list_teams", %{"member" => "ALICE"}, @read_ctx)
      assert team.slug == "alpha"
    end

    test "filters by project" do
      Factory.insert!(:team, slug: "alpha", projects: ["repo-a"])
      Factory.insert!(:team, slug: "beta", projects: ["repo-b"])

      assert {:ok, [team]} = Tools.call("list_teams", %{"project" => "repo-b"}, @read_ctx)
      assert team.slug == "beta"
    end
  end

  describe "list_commits new filters" do
    test "filters by repo" do
      Factory.insert!(:commit, repo: "repo-a")
      Factory.insert!(:commit, repo: "repo-b")

      {:ok, commits} = Tools.call("list_commits", %{"repo" => "repo-a"}, @read_ctx)
      assert length(commits) == 1
      assert hd(commits).repo == "repo-a"
    end

    test "filters by projects_of_team (includes unclaimed)" do
      Factory.insert!(:team, slug: "devops", projects: ["repo-a"])
      Factory.insert!(:team, slug: "other", projects: ["repo-b"])

      in_team = Factory.insert!(:commit, repo: "repo-a")
      _in_other = Factory.insert!(:commit, repo: "repo-b")
      unclaimed = Factory.insert!(:commit, repo: "ownerless")

      {:ok, commits} =
        Tools.call("list_commits", %{"projects_of_team" => "devops"}, @read_ctx)

      ids = Enum.map(commits, & &1.id) |> Enum.sort()
      assert ids == Enum.sort([in_team.id, unclaimed.id])
    end

    test "filters by members_of_team" do
      Factory.insert!(:team, slug: "devops", usernames: ["alice"])

      mine = Factory.insert!(:commit, usernames: ["alice"])
      _theirs = Factory.insert!(:commit, usernames: ["bob"])

      {:ok, commits} =
        Tools.call("list_commits", %{"members_of_team" => "devops"}, @read_ctx)

      assert Enum.map(commits, & &1.id) == [mine.id]
    end

    test "status: unreviewed returns only unreviewed" do
      u = Factory.insert!(:commit, reviewed_at: nil)
      _r = Factory.insert!(:commit, reviewed_at: DateTime.utc_now(), reviewed_by_username: "x")

      {:ok, commits} = Tools.call("list_commits", %{"status" => "unreviewed"}, @read_ctx)

      assert Enum.map(commits, & &1.id) == [u.id]
    end

    test "status: reviewed returns only reviewed" do
      _u = Factory.insert!(:commit, reviewed_at: nil)
      r = Factory.insert!(:commit, reviewed_at: DateTime.utc_now(), reviewed_by_username: "x")

      {:ok, commits} = Tools.call("list_commits", %{"status" => "reviewed"}, @read_ctx)

      assert Enum.map(commits, & &1.id) == [r.id]
    end
  end

  describe "list_comments new filters" do
    test "filters by repo" do
      mine = Factory.insert!(:comment_notification, username: "octocat")
      Repo.get!(Remit.Commit, mine.comment.commit.id)
      |> Ecto.Changeset.change(repo: "repo-a")
      |> Repo.update!()

      other = Factory.insert!(:comment_notification, username: "octocat")
      Repo.get!(Remit.Commit, other.comment.commit.id)
      |> Ecto.Changeset.change(repo: "repo-b")
      |> Repo.update!()

      {:ok, notifications} = Tools.call("list_comments", %{"repo" => "repo-a"}, @read_ctx)

      assert Enum.map(notifications, & &1.id) == [mine.id]
    end
  end

  describe "missing id" do
    test "stale integer commit id returns :bad_request (not raised)" do
      assert {:error, :bad_request, msg} =
               Tools.call("mark_reviewed", %{"id" => 999_999_999}, @review_ctx)

      assert msg =~ "no commit found"
    end

    test "junk id string returns :bad_request via SHA-prefix path" do
      assert {:error, :bad_request, _} =
               Tools.call("mark_reviewed", %{"id" => "not-a-sha"}, @review_ctx)
    end

    test "junk id string for resolve_comment returns :bad_request" do
      assert {:error, :bad_request, msg} =
               Tools.call("resolve_comment", %{"id" => "abc"}, @review_ctx)

      assert msg =~ "id must be an integer"
    end
  end

  describe "limit clamping" do
    test "list_commits clamps to the configured max" do
      max = Application.get_env(:remit, :max_commits)

      for _ <- 1..(max + 1), do: Factory.insert!(:commit)

      {:ok, commits} =
        Tools.call("list_commits", %{"limit" => max * 10}, @read_ctx)

      assert length(commits) == max
    end

    test "list_comments clamps to the configured max" do
      max = Application.get_env(:remit, :max_comments)

      for _ <- 1..(max + 1), do: Factory.insert!(:comment_notification, username: "octocat")

      {:ok, notifications} =
        Tools.call("list_comments", %{"limit" => max * 10}, @read_ctx)

      assert length(notifications) == max
    end

    test "list_commits with non-integer limit returns :bad_request" do
      assert {:error, :bad_request, _} =
               Tools.call("list_commits", %{"limit" => "junk"}, @read_ctx)
    end
  end

  describe "SHA-prefix lookup" do
    test "resolves a SHA prefix to a commit" do
      commit = Factory.insert!(:commit, repo: "ownerless", sha: "abcdef0123456789")

      prefix = String.slice(commit.sha, 0, 8)

      assert {:ok, payload} =
               Tools.call("mark_reviewed", %{"id" => prefix}, @review_ctx)

      assert payload.id == commit.id
    end

    test "unknown SHA prefix returns :bad_request (not raised)" do
      assert {:error, :bad_request, msg} =
               Tools.call("mark_reviewed", %{"id" => "deadbeef"}, @review_ctx)

      assert msg =~ "no commit found"
    end

    test "ambiguous SHA prefix returns :bad_request" do
      Factory.insert!(:commit, repo: "ownerless", sha: "fffaaaa1234567890")
      Factory.insert!(:commit, repo: "ownerless", sha: "fffaaaa9999888777")

      assert {:error, :bad_request, msg} =
               Tools.call("mark_reviewed", %{"id" => "fffaaaa"}, @review_ctx)

      assert msg =~ "ambiguous"
    end

    test "non-hex string returns :bad_request" do
      assert {:error, :bad_request, _} =
               Tools.call("mark_reviewed", %{"id" => "not-a-sha"}, @review_ctx)
    end
  end

  describe "unknown tool" do
    test "returns :unknown_tool" do
      assert {:error, :unknown_tool, _} = Tools.call("nope", %{}, @read_ctx)
    end
  end
end
