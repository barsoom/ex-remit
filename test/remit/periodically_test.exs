defmodule Remit.PeriodicallyTest do
  # Can't (?) be async because we use the DB from another process.
  use Remit.DataCase
  alias Remit.Factory

  # Tested in more detail in `Commits.delete_older_than_days`.
  test "periodically removes old data" do
    older_unreviewed_commit = Factory.insert!(:commit, inserted_at: days_ago(11), reviewed_at: nil)
    older_reviewed_commit = Factory.insert!(:commit, inserted_at: days_ago(11), reviewed_at: some_time())
    newer_reviewed_commit = Factory.insert!(:commit, inserted_at: days_ago(9), reviewed_at: some_time())

    start_supervised!({Remit.Periodically, frequency_ms: 5, days_string: "10"})
    assert in_db?(older_unreviewed_commit)
    assert in_db?(older_reviewed_commit)
    assert in_db?(newer_reviewed_commit)

    :timer.sleep(10)
    assert in_db?(older_unreviewed_commit)
    refute in_db?(older_reviewed_commit)
    assert in_db?(newer_reviewed_commit)
  end

  test "does nothing if no days are given" do
    commit = Factory.insert!(:commit, inserted_at: days_ago(999), reviewed_at: some_time())

    start_supervised!({Remit.Periodically, frequency_ms: 1, days_string: nil})
    assert in_db?(commit)

    :timer.sleep(10)
    assert in_db?(commit)
  end

  defp some_time, do: DateTime.utc_now()

  defp days_ago(days) do
    DateTime.utc_now()
    |> DateTime.add(-days * 60 * 60 * 24)
  end

  defp in_db?(record), do: Repo.exists?(from record.__struct__, where: [id: ^record.id])
end
