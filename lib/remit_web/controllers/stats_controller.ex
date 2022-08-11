defmodule RemitWeb.StatsController do
  use RemitWeb, :controller
  alias Remit.{Repo, Commits, Commit}
  import Ecto.Query

  @max_commits Application.compile_env(:remit, :max_commits)

  def show(conn, params) do
    max_commits = params["max_commits_for_tests"] || @max_commits

    commits = Commits.list_latest(max_commits)
    unreviewed_commits = commits |> Enum.reject(& &1.reviewed_at)

    unreviewed_count = unreviewed_commits |> length()
    reviewable_count = unreviewed_commits |> Enum.reject(& &1.review_started_at) |> length()

    oldest_unreviewed_inserted_at = unreviewed_commits |> Enum.map(& &1.inserted_at) |> Enum.min(DateTime, fn -> nil end)
    oldest_unreviewed_in_seconds = oldest_unreviewed_inserted_at && DateTime.diff(DateTime.utc_now(), oldest_unreviewed_inserted_at)

    oldest_unreviewed = unreviewed_commits |> List.last()

    commits_until_oldest_unreviewed_falls_outside_window =
      if oldest_unreviewed do
        index_of_oldest_unreviewed = Enum.find_index(commits, &(&1 == oldest_unreviewed))
        length(commits) - index_of_oldest_unreviewed
      else
        nil
      end

    per_reviewer_counts =
      Commit.listed()
      |> where([c], c.updated_at > ago(10, "day"))
      |> group_by([c], fragment("LOWER(reviewed_by_username)"))
      |> select([c], {fragment("LOWER(reviewed_by_username)"), count(c.id)})
      |> Repo.all()

    recent_commits_count = per_reviewer_counts |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    recent_reviews =
      per_reviewer_counts
      |> Enum.filter(&elem(&1, 0))
      |> Enum.into(%{})

    conn
    |> json(%{
      "unreviewed_count" => unreviewed_count,
      "reviewable_count" => reviewable_count,
      "oldest_unreviewed_in_seconds" => oldest_unreviewed_in_seconds,
      "commits_until_oldest_unreviewed_falls_outside_window" => commits_until_oldest_unreviewed_falls_outside_window,
      "recent_commits_count" => recent_commits_count,
      "recent_reviews" => recent_reviews
    })
  end
end
