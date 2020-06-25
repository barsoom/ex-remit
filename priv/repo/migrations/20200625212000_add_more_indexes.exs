defmodule Remit.Repo.Migrations.AddMoreIndexes do
  use Ecto.Migration

  def change do
    create index(:comment_notifications, [:comment_id])
  end
end
