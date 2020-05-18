defmodule Remit.Settings do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Remit.{Repo,Settings}

  @stale_after_days 100

  schema "settings" do
    field :email, :string
    field :name, :string
    field :read_at, :utc_datetime_usec
    field :session_id, Ecto.UUID

    timestamps()
  end

  @doc false
  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:name, :email, :session_id, :read_at])
    |> validate_required([:session_id])
  end

  def for_session(%{"session_id" => sid}) do
    settings = Repo.get_by(Settings, session_id: sid)

    if settings do
      now = DateTime.utc_now()

      # Update `read_at` so we can track stale Settings.
      settings = settings |> Ecto.Changeset.change(read_at: now) |> Repo.update!

      # Delete stale Settings so DB doesn't keep them forever. It's cheap enough to do on every call.
      stale_before = now |> DateTime.add(-60 * 60 * 24 * @stale_after_days, :second)
      Repo.delete_all(from s in Settings, where: s.read_at < ^stale_before)

      settings
    else
      %Settings{session_id: sid}
    end
  end
end
