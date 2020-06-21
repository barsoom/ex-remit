defmodule Remit.Repo do
  use Ecto.Repo,
    otp_app: :remit,
    adapter: Ecto.Adapters.Postgres
end
