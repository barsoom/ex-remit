defmodule Remit.Commits do
  alias Remit.{Repo, Commit}
  import Ecto.Query

  def list_latest(count) do
    Repo.all(from Commit, limit: ^count, order_by: [desc: :id])
  end

  def list_latest_shas(count) do
    Repo.all(from Commit, limit: ^count, order_by: [desc: :id], select: [:sha])
    |> Enum.map(& &1.sha)
  end
end
