defmodule RemitWeb.LiveViewHelpersTest do
  use ExUnit.Case, async: true
  alias RemitWeb.LiveViewHelpers

  describe "github_avatar" do
    test "generates an img" do
      html = LiveViewHelpers.github_avatar("foo", 123) |> to_s()
      assert html =~ ~s{<img}
      assert html =~ ~s{src="https://github.com/foo.png?size=123"}
    end

    test "uses the 'dependabot' avatar for 'dependabot-preview'" do
      html = LiveViewHelpers.github_avatar("dependabot-preview", 123) |> to_s()
      assert html =~ "dependabot.png"
    end

    defp to_s(safe), do: Phoenix.HTML.safe_to_string(safe)
  end

  # The numbers come from config, so derive them rather than hardcoding — these tests are about
  # the mechanism, not about any particular default.
  defp default_days, do: LiveViewHelpers.default_reviewed_commit_cutoff()["days"]
  defp default_commits, do: LiveViewHelpers.default_reviewed_commit_cutoff()["commits"]

  describe "get_reviewed_commit_cutoff/1" do
    test "defaults to both cutoffs switched on, at the configured numbers" do
      assert LiveViewHelpers.get_reviewed_commit_cutoff(%{}) == %{
               "days" => default_days(),
               "commits" => default_commits(),
               "days_enabled" => true,
               "commits_enabled" => true
             }
    end

    test "a legacy stored 0 comes back as switched off, not ticked-but-inactive" do
      # 0 was how you disabled a cutoff before the checkboxes existed.
      session = %{"reviewed_commit_cutoff" => %{"days" => 0, "commits" => 50}}
      cutoff = LiveViewHelpers.get_reviewed_commit_cutoff(session)

      assert cutoff["days_enabled"] == false
      assert cutoff["commits_enabled"] == true
    end

    test "an explicit flag wins over the number" do
      session = %{"reviewed_commit_cutoff" => %{"days" => 7, "days_enabled" => false}}
      assert LiveViewHelpers.get_reviewed_commit_cutoff(session)["days_enabled"] == false
    end

    test "the session overrides the defaults" do
      session = %{"reviewed_commit_cutoff" => %{"days" => 30}}
      cutoff = LiveViewHelpers.get_reviewed_commit_cutoff(session)

      assert cutoff["days"] == 30
      assert cutoff["days_enabled"] == true
      # untouched keys keep their defaults
      assert cutoff["commits"] == default_commits()
      assert cutoff["commits_enabled"] == true
    end

    test "a switched-off cutoff comes back at its default, ready to switch on" do
      session = %{"reviewed_commit_cutoff" => %{"days" => 30, "days_enabled" => false}}
      cutoff = LiveViewHelpers.get_reviewed_commit_cutoff(session)

      assert cutoff["days_enabled"] == false
      assert cutoff["days"] == default_days()
    end
  end

  describe "normalize_cutoff/2" do
    test "0 switches the cutoff off and restores a usable number" do
      cutoff = LiveViewHelpers.normalize_cutoff(%{"days" => 0, "days_enabled" => true}, "days")

      assert cutoff["days_enabled"] == false
      # so that switching it back on gives a working cutoff rather than a silently inactive one
      assert cutoff["days"] == default_days()
    end

    test "a negative or missing number is treated the same as 0" do
      assert LiveViewHelpers.normalize_cutoff(%{"commits" => -5}, "commits") ==
               %{"commits" => default_commits(), "commits_enabled" => false}

      assert LiveViewHelpers.normalize_cutoff(%{}, "commits") ==
               %{"commits" => default_commits(), "commits_enabled" => false}
    end

    test "a positive number that is switched on is left alone" do
      cutoff = %{"days" => 30, "days_enabled" => true}
      assert LiveViewHelpers.normalize_cutoff(cutoff, "days") == cutoff
    end

    test "switching off restores the default number" do
      cutoff = LiveViewHelpers.normalize_cutoff(%{"days" => 30, "days_enabled" => false}, "days")

      assert cutoff == %{"days" => default_days(), "days_enabled" => false}
    end

    test "only touches the key it is given" do
      cutoff = LiveViewHelpers.normalize_cutoff(%{"days" => 0, "commits" => 50}, "days")

      assert cutoff["commits"] == 50
      refute Map.has_key?(cutoff, "commits_enabled")
    end

    test "switching on can never leave an inactive cutoff" do
      # The invariant the whole thing exists for.
      for value <- [0, -1, nil] do
        cutoff = LiveViewHelpers.normalize_cutoff(%{"days" => value, "days_enabled" => true}, "days")
        assert cutoff["days_enabled"] == false
        assert LiveViewHelpers.cutoff_enabled?(Map.put(cutoff, "days_enabled", true), "days")
      end
    end
  end

  describe "cutoff_enabled?/2" do
    test "true only when switched on and a positive number" do
      assert LiveViewHelpers.cutoff_enabled?(%{"days" => 7, "days_enabled" => true}, "days")
      refute LiveViewHelpers.cutoff_enabled?(%{"days" => 7, "days_enabled" => false}, "days")
      refute LiveViewHelpers.cutoff_enabled?(%{"days" => 0, "days_enabled" => true}, "days")
    end

    test "a switched-off cutoff does not apply, whatever its number" do
      refute LiveViewHelpers.cutoff_enabled?(%{"commits" => 100, "commits_enabled" => false}, "commits")
    end

    test "sessions predating the checkboxes still apply their cutoffs" do
      assert LiveViewHelpers.cutoff_enabled?(%{"days" => 7}, "days")
      refute LiveViewHelpers.cutoff_enabled?(%{"days" => 0}, "days")
    end
  end
end
