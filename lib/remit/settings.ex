defmodule Remit.Settings do
  use Ecto.Schema
  import Ecto.Changeset
  alias Remit.{Repo,Settings}

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
    Repo.get_by(Settings, session_id: sid) || %Settings{session_id: sid}
  end
end
