defmodule Remit.Repo.Migrations.AddResolvedStateToComments do
  use Ecto.Migration

  def change do
    alter table(:comments) do
      add :resolved_at, :utc_datetime
      add :resolved_by, :string
    end
  end
end
