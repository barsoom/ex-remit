defmodule Remit.Repo.Migrations.AddDeployedShaToCommits do
  use Ecto.Migration

  def change do
    alter table(:commits) do
      add :deployed_sha, :string
    end

    create index(:commits, [:deployed_sha])
  end
end
