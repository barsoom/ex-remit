defmodule Remit.Repo.Migrations.AddUsersToTeams do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :usernames, {:array, :string}, null: false, default: []
    end
  end
end
