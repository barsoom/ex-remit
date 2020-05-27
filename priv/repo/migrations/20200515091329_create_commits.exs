defmodule Remit.Repo.Migrations.CreateCommits do
  use Ecto.Migration

  def change do
    create table(:commits) do
      add :sha, :string, null: false
      add :author_email, :string, null: false
      add :author_name, :string, null: false
      add :author_usernames, {:array, :string}, null: false
      add :owner, :string, null: false
      add :repo, :string, null: false
      add :message, :text, null: false
      add :url, :text, null: false
      add :committed_at, :utc_datetime, null: false

      add :review_started_at, :utc_datetime
      add :reviewed_at, :utc_datetime
      add :review_started_by_email, :string
      add :reviewed_by_email, :string

      timestamps(type: :utc_datetime)
    end
  end
end
