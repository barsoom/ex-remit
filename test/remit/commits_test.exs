defmodule Remit.CommitsTest do
  use Remit.DataCase, async: true
  alias Remit.{Commits, Factory}

  describe "list_latest_shas" do
    test "returns up to the given number of recent SHAs" do
      Factory.insert!(:commit, sha: "abc1")
      Factory.insert!(:commit, sha: "abc2")

      assert Commits.list_latest_shas(1) == ["abc2"]
      assert Commits.list_latest_shas(2) == ["abc2", "abc1"]
      assert Commits.list_latest_shas(99) == ["abc2", "abc1"]
    end
  end
end
