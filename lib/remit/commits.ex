defmodule Remit.Commits do
  @moduledoc false
  alias Remit.{Repo, Commit}
  import Ecto.Query

  def list_latest(count) do
    Commit.latest_listed(count)
    |> Repo.all()
  end

  def list_latest(filters, count)

  def list_latest(filters, count) do
    filtered =
      filters
      |> Enum.reduce(Commit.listed(), &Commit.apply_filter(&2, &1))

    unreviewed =
      filtered
      |> where([c], is_nil(c.reviewed_at))

    reviewed =
      filtered
      |> where([c], not is_nil(c.reviewed_at))
      |> Commit.apply_reviewed_cutoff(filters)
      |> order_by([c], desc: c.id)

    subquery(union_all(unreviewed, ^reviewed))
    |> order_by([u], desc: u.id)
    |> limit(^count)
    |> Repo.all()
  end

  def list_latest_shas(count) do
    Commit.latest_listed(count)
    |> select([c], c.sha)
    |> Repo.all()
  end

  def sha_exists?(sha), do: Repo.exists?(from Commit, where: [sha: ^sha])

  def delete_reviewed_older_than_days(days) when is_integer(days) do
    Repo.delete_all(from c in Commit, where: c.inserted_at < ago(^days, "day"), where: not is_nil(c.reviewed_at))
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

  # No-op.
  def broadcast_new_commits([]), do: nil

  def broadcast_new_commits(commits) do
    Phoenix.PubSub.broadcast_from!(Remit.PubSub, self(), "commits", {:new_commits, commits})
  end

  # Private

  defp update!(id, attributes) do
    Repo.get_by(Commit, id: id)
    |> Ecto.Changeset.change(attributes)
    |> Repo.update!()
  end

  defp now, do: DateTime.utc_now()
end
