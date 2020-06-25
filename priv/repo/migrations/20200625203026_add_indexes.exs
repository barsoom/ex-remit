defmodule Remit.Repo.Migrations.AddIndexes do
  use Ecto.Migration

  def change do
    # An attempt to make `Comments.list_notifications` queries more performant.

    # Filtered and sorted on.
    create index(:comment_notifications, [:resolved_at])
  end
end
