defmodule Remit.CommitTest do
  use ExUnit.Case, async: true
  alias Remit.Commit

  describe "message_summary" do
    test "extracts the first line of the message" do
      assert Commit.message_summary(%Commit{message: "My summary\nMore info"}) == "My summary"
      assert Commit.message_summary(%Commit{message: "My summary\rMore info"}) == "My summary"
      assert Commit.message_summary(%Commit{message: "My summary\r\nMore info"}) == "My summary"
    end
  end

  describe "authored_by?" do
    test "is true if you're among the author usernames, case-insensitive" do
      commit = %Commit{author_usernames: ["foo", "bar"]}
      assert Commit.authored_by?(commit, "foo")
      assert Commit.authored_by?(commit, "bar")
      assert Commit.authored_by?(commit, "BAr")
      refute Commit.authored_by?(commit, "baz")
      refute Commit.authored_by?(commit, nil)
    end
  end
end
