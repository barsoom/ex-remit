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
        "oldest_unreviewed_in_seconds" => fragment("ROUND(EXTRACT(EPOCH FROM (TIMEZONE('utc', NOW()) - MIN(inserted_at))))"),
      })
      |> Repo.one()

    json(conn, data)
  end
end
