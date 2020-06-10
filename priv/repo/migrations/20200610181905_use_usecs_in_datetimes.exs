defmodule Remit.Repo.Migrations.UseUsecsInDatetimes do
  use Ecto.Migration

  def change do
    alter table(:commits) do
      modify :committed_at, :utc_datetime_usec
      modify :review_started_at, :utc_datetime_usec
      modify :reviewed_at, :utc_datetime_usec
      modify :inserted_at, :utc_datetime_usec
      modify :updated_at, :utc_datetime_usec
    end

    alter table(:comments) do
      modify :commented_at, :utc_datetime_usec
      modify :inserted_at, :utc_datetime_usec
      modify :updated_at, :utc_datetime_usec
    end

    alter table(:comment_notifications) do
      modify :resolved_at, :utc_datetime_usec
      modify :inserted_at, :utc_datetime_usec
      modify :updated_at, :utc_datetime_usec
    end
  end
end
