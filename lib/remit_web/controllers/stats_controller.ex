defmodule RemitWeb.StatsController do
  use RemitWeb, :controller
  alias Remit.{Repo, Commit}
  import Ecto.Query

  def show(conn, _params) do
    unreviewed_count =
      Commit
      |> where([c], is_nil(c.reviewed_at))
      |> Repo.aggregate(:count)

    conn
    |> json(%{
      "unreviewed_count" => unreviewed_count,
    })
  end
end
