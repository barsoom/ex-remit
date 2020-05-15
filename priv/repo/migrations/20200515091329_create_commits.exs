defmodule Remit.Repo.Migrations.CreateCommits do
  use Ecto.Migration

  def change do
    create table(:commits) do
      add :sha, :string, null: false
      add :payload, :map, null: false
      add :review_started_at, :utc_datetime
      add :reviewed_at, :utc_datetime
      add :author_id, references(:authors, on_delete: :nothing)
      add :review_started_by_author_id, references(:authors, on_delete: :nothing)
      add :reviewed_by_author_id, references(:authors, on_delete: :nothing)

      timestamps()
    end

    create index(:commits, [:author_id])
    create index(:commits, [:review_started_by_author_id])
    create index(:commits, [:reviewed_by_author_id])
  end
end
