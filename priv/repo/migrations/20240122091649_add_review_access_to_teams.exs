defmodule Remit.Repo.Migrations.AddReviewAccessToTeams do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE review_access AS ENUM ('public', 'team')",
            "DROP TYPE review_access"

    alter table(:teams) do
      add :review_access, :review_access, null: false, default: "public"
    end
  end
end
