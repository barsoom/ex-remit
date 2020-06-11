defmodule Remit.Repo.Migrations.ReplaceCommitEmailFieldsWithUsername do
  use Ecto.Migration

  def change do
    alter table(:commits) do
      add :review_started_by_username, :string
      add :reviewed_by_username, :string

      remove :review_started_by_email, :string
      remove :reviewed_by_email, :string
      remove :author_email, :string, null: false
    end
  end
end
