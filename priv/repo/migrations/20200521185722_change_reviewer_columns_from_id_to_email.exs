defmodule Remit.Repo.Migrations.ChangeReviewerColumnsFromIdToEmail do
  use Ecto.Migration

  def change do
    alter table("commits") do
      add :reviewed_by_email, :string
      add :review_started_by_email, :string
      remove :review_started_by_author_id
      remove :reviewed_by_author_id
    end
  end
end
