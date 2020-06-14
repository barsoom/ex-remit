defmodule Remit.PeriodicallyTest do
  # Can't (?) be async because we use the DB from another process.
  use Remit.DataCase
  alias Remit.Factory

  # Tested in more detail in `Commits.delete_older_than_days`.
  test "periodically removes old data" do
    older_commit = Factory.insert!(:commit, inserted_at: days_ago(11))
    newer_commit = Factory.insert!(:commit, inserted_at: days_ago(9))

    Remit.Periodically.start_link(frequency_ms: 5, days_string: "10")
    assert in_db?(older_commit)
    assert in_db?(newer_commit)

    :timer.sleep(10)
    refute in_db?(older_commit)
    assert in_db?(newer_commit)
  end

  test "does nothing if no days are given" do
    commit = Factory.insert!(:commit, inserted_at: days_ago(999))

    Remit.Periodically.start_link(frequency_ms: 1, days_string: nil)
    assert in_db?(commit)

    :timer.sleep(10)
    assert in_db?(commit)
  end

  defp days_ago(days) do
    DateTime.utc_now()
    |> DateTime.add(-days * 60 * 60 * 24)
  end

  defp in_db?(record), do: Repo.exists?(from record.__struct__, where: [id: ^record.id])
end
