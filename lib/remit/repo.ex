defmodule Remit.Repo do
  use Ecto.Repo,
    otp_app: :remit,
    adapter: Ecto.Adapters.Postgres

  import Ecto.Query
  alias __MODULE__

  # Convenient in a console.
  def last(q) do
    Repo.one(from q, order_by: [desc: :id], limit: 1)
  end
end
