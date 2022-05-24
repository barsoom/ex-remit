defmodule Remit.CommitTest do
  use ExUnit.Case, async: true
  alias Remit.Commit

  describe "message_summary" do
    test "extracts the first line of the message" do
      assert Commit.message_summary(%Commit{message: "My summary\nMore info"}) == "My summary"
      assert Commit.message_summary(%Commit{message: "My summary\rMore info"}) == "My summary"
      assert Commit.message_summary(%Commit{message: "My summary\r\nMore info"}) == "My summary"
    end

    # Regression.
    test "doesn't make a mess when encountering the letter 'Å'" do
      assert Commit.message_summary(%Commit{message: "Åland\nIt's a place."}) == "Åland"
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
          %Commit{id: 1, committed_at: ~U[2020-06-10 12:00:00.000000Z]}
        ])
        |> Enum.map(&{&1.id, &1.date_separator_before}) == [
          {5, ~D[2020-06-12]},
          {4, nil},
          {3, ~D[2020-06-11]},
          {2, nil},
          {1, ~D[2020-06-10]}
        ]
      )
    end

    test "uses CET dates" do
      assert(
        Commit.add_date_separators([
          %Commit{id: 2, committed_at: ~U[2020-06-12 23:01:00.000000Z]},
          %Commit{id: 1, committed_at: ~U[2020-06-12 23:00:00.000000Z]}
        ])
        |> Enum.map(&{&1.id, &1.date_separator_before}) == [
          {2, ~D[2020-06-13]},
          {1, nil}
        ]
      )
    end

    test "overwrites any previous 'date_separator_before'" do
      assert(
        Commit.add_date_separators([
          %Commit{id: 2, committed_at: ~U[2020-06-12 23:01:00.000000Z], date_separator_before: nil},
          %Commit{id: 1, committed_at: ~U[2020-06-12 23:00:00.000000Z], date_separator_before: :foo}
        ])
        |> Enum.map(&{&1.id, &1.date_separator_before}) == [
          {2, ~D[2020-06-13]},
          {1, nil}
        ]
      )
    end
  end

  describe "oldest_unreviewed_for" do
    test "it returns the oldest (by list order) commit for the given user to review" do
      time = DateTime.utc_now()

      commits = [
        _newer = %Commit{id: 5},
        oldest_unreviewed_for_me = %Commit{id: 4},
        _older_but_authored_by_me = %Commit{id: 3, usernames: ["myname"]},
        _older_but_review_started = %Commit{id: 2, review_started_at: time},
        _older_but_reviewed = %Commit{id: 1, reviewed_at: time}
      ]

      assert Commit.oldest_unreviewed_for(commits, "myname") == oldest_unreviewed_for_me
    end

    test "it can find a review-started commit if the given user started it" do
      time = DateTime.utc_now()

      commits = [
        _review_not_started = %Commit{id: 3},
        oldest_unreviewed_for_me = %Commit{id: 2, review_started_at: time, review_started_by_username: "myname"},
        _older_but_started_by_someone_else = %Commit{id: 1, review_started_at: time}
      ]

      assert Commit.oldest_unreviewed_for(commits, "myname") == oldest_unreviewed_for_me
    end

    test "returns nil when there's nothing" do
      assert Commit.oldest_unreviewed_for([], "myname") == nil
    end

    test "returns nil for a nil user" do
      commits = [
        %Commit{id: 1}
      ]

      assert Commit.oldest_unreviewed_for(commits, nil) == nil
    end
  end

  describe "oldest_overlong_in_review_by" do
    setup do: %{now: ~U[2020-06-30 12:00:00.000000Z]}

    test "returns the oldest (by list order) commit that has been in review by the given user for over 15 minutes", %{now: now} do
      commits = [
        _just_under = %Commit{review_started_by_username: "myname", review_started_at: ~U[2020-06-30 11:45:00.000000Z]},
        _overlong_but_newer = %Commit{review_started_by_username: "myname", review_started_at: ~U[2020-06-30 11:44:59.999999Z]},
        overlong = %Commit{review_started_by_username: "myname", review_started_at: ~U[2020-06-30 11:44:59.999998Z]},
        _by_another = %Commit{review_started_by_username: "theirname", review_started_at: ~U[2020-06-30 11:44:57.000000Z]},
        _reviewed = %Commit{review_started_by_username: "myname", review_started_at: ~U[2020-06-30 11:44:57.000000Z], reviewed_at: now}
      ]

      assert Commit.oldest_overlong_in_review_by(commits, "myname", now) == overlong
    end

    test "returns nil when there's nothing", %{now: now} do
      assert Commit.oldest_overlong_in_review_by([], "myname", now) == nil
    end

    test "returns nil for a nil user", %{now: now} do
      commits = [
        %Commit{id: 1}
      ]

      assert Commit.oldest_overlong_in_review_by(commits, nil, now) == nil
    end
  end
end
