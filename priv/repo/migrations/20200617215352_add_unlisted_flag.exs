defmodule Remit.Repo.Migrations.AddUnlistedFlag do
  use Ecto.Migration

  def change do
    alter table(:commits) do
      add :unlisted, :boolean, null: false, default: false
    end
  end
end
