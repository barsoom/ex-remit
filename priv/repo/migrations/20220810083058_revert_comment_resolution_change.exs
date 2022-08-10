defmodule Remit.Repo.Migrations.RevertCommentResolutionChange do
  use Ecto.Migration

  def change do
    alter table(:comments) do
      remove :resolved_at, :utc_datetime
      remove :resolved_by, :string
    end
  end
end
