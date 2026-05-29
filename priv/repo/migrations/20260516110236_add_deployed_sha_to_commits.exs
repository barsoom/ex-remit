defmodule Remit.Repo.Migrations.AddDeployedShaToCommits do
  use Ecto.Migration

  def change do
    alter table(:commits) do
      add :deployed_sha, :string
      add :deployed_repo, :string
    end

    create index(:commits, [:deployed_sha])
    create index(:commits, [:deployed_repo])
  end
end
