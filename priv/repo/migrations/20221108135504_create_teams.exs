defmodule Remit.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams) do
      add :slug, :string, null: false
      add :name, :string, null: false
      add :projects, {:array, :string}, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
