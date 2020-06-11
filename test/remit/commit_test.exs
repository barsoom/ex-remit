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
    test "is true if you're among the usernames, case-insensitive" do
      commit = %Commit{usernames: ["foo", "bar"]}
      assert Commit.authored_by?(commit, "foo")
      assert Commit.authored_by?(commit, "bar")
      assert Commit.authored_by?(commit, "BAr")
      refute Commit.authored_by?(commit, "baz")
      refute Commit.authored_by?(commit, nil)
    end
  end

  describe "add_date_separators" do
    test "sets 'date_separator_before' to the date, in the first commit on each date" do
      assert(
        Commit.add_date_separators([
          %Commit{id: 5, committed_at: ~U[2020-06-12 13:00:00.000000Z]},
          %Commit{id: 4, committed_at: ~U[2020-06-12 12:00:00.000000Z]},
          %Commit{id: 3, committed_at: ~U[2020-06-11 13:00:00.000000Z]},
          %Commit{id: 2, committed_at: ~U[2020-06-11 12:00:00.000000Z]},
          %Commit{id: 1, committed_at: ~U[2020-06-10 12:00:00.000000Z]},
        ]) |> Enum.map(& {&1.id, &1.date_separator_before}) == [
          {5, ~D[2020-06-12]},
          {4, nil},
          {3, ~D[2020-06-11]},
          {2, nil},
          {1, ~D[2020-06-10]},
        ]
      )
    end

    test "uses CET dates" do
      assert(
        Commit.add_date_separators([
          %Commit{id: 2, committed_at: ~U[2020-06-12 23:01:00.000000Z]},
          %Commit{id: 1, committed_at: ~U[2020-06-12 23:00:00.000000Z]},
        ]) |> Enum.map(& {&1.id, &1.date_separator_before}) == [
          {2, ~D[2020-06-13]},
          {1, nil},
        ]
      )
    end

    test "overwrites any previous 'date_separator_before'" do
      assert(
        Commit.add_date_separators([
          %Commit{id: 2, committed_at: ~U[2020-06-12 23:01:00.000000Z], date_separator_before: nil},
          %Commit{id: 1, committed_at: ~U[2020-06-12 23:00:00.000000Z], date_separator_before: :foo},
        ]) |> Enum.map(& {&1.id, &1.date_separator_before}) == [
          {2, ~D[2020-06-13]},
          {1, nil},
        ]
      )
    end
  end
end
