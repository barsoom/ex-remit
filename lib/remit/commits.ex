defmodule Remit.Commits do
  alias Remit.{Repo, Commit}
  import Ecto.Query

  def list_latest(count) do
    Commit.latest(count) |> Repo.all()
  end

  def list_latest_shas(count) do
    Repo.all(from c in Commit.latest(count), select: c.sha)
  end

  def mark_as_reviewed!(id, reviewer_email) when is_binary(reviewer_email) do
    update!(id, reviewed_at: now(), reviewed_by_email: reviewer_email)
  end

  def mark_as_unreviewed!(id) do
    update!(id, reviewed_at: nil, review_started_at: nil, reviewed_by_email: nil, review_started_by_email: nil)
  end

  def mark_as_review_started!(id, reviewer_email) when is_binary(reviewer_email) do
    update!(id, review_started_at: now(), review_started_by_email: reviewer_email)
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
