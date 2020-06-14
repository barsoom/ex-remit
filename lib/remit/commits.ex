defmodule Remit.Commits do
  alias Remit.{Repo, Commit}
  import Ecto.Query

  def list_latest(count) do
    Commit.latest(count) |> Repo.all()
  end

  def list_latest_shas(count) do
    Repo.all(from c in Commit.latest(count), select: c.sha)
  end

  def delete_older_than_days(days) when is_integer(days) do
    Repo.delete_all(from c in Commit, where: c.inserted_at < ago(^days, "day"))
  end

  def mark_as_reviewed!(id, reviewer_username) when is_binary(reviewer_username) do
    update!(id, reviewed_at: now(), reviewed_by_username: reviewer_username)
  end

  def mark_as_unreviewed!(id) do
    update!(id, reviewed_at: nil, review_started_at: nil, reviewed_by_username: nil, review_started_by_username: nil)
  end

  def mark_as_review_started!(id, reviewer_username) when is_binary(reviewer_username) do
    update!(id, review_started_at: now(), review_started_by_username: reviewer_username)
  end

  def subscribe, do: Phoenix.PubSub.subscribe(Remit.PubSub, "commits")

  def broadcast_changed_commit(commit) do
    Phoenix.PubSub.broadcast_from!(Remit.PubSub, self(), "commits", {:changed_commit, commit})
  end

  def broadcast_new_commits([]), do: nil  # No-op.
  def broadcast_new_commits(commits) do
    Phoenix.PubSub.broadcast_from!(Remit.PubSub, self(), "commits", {:new_commits, commits})
  end

  # Private

  defp update!(id, attributes) do
    Repo.get_by(Commit, id: id)
    |> Ecto.Changeset.change(attributes)
    |> Repo.update!()
  end

  defp now(), do: DateTime.utc_now()
end
