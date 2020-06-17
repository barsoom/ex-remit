defmodule RemitWeb.StatsController do
  use RemitWeb, :controller
  alias Remit.{Repo, Commit}
  import Ecto.Query

  def show(conn, _params) do
    data =
      Commit
      |> where([c], is_nil(c.reviewed_at))
      |> select([c], %{
        "unreviewed_count" => count(c.id),
        "oldest_unreviewed_in_seconds" => fragment("ROUND(EXTRACT(EPOCH FROM (TIMEZONE('utc', NOW()) - MIN(inserted_at)))::numeric)::integer"),
      })
      |> Repo.one()

    per_reviewer_counts =
      Commit
      |> where([c], c.updated_at > ago(10, "day"))
      |> group_by([c], fragment("LOWER(reviewed_by_username)"))
      |> select([c], {fragment("LOWER(reviewed_by_username)"), count(c.id)})
      |> Repo.all()

    recent_commits_count = per_reviewer_counts |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    recent_reviews =
      per_reviewer_counts
      |> Enum.filter(&elem(&1, 0))
      |> Enum.into(%{})

    data = Map.merge(data, %{
      "recent_commits_count" => recent_commits_count,
      "recent_reviews" => recent_reviews,
    })

    json(conn, data)
  end
end
