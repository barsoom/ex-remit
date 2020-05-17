defmodule Remit.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :name, :string
      add :email, :string
      add :session_id, :uuid, null: false
      add :read_at, :utc_datetime_usec

      timestamps()
    end

  end
end
