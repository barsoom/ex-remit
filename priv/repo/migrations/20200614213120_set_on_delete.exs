defmodule Remit.Repo.Migrations.SetOnDelete do
  use Ecto.Migration

  def change do
    drop index(:commits, [:sha])
    create unique_index(:commits, [:sha])

    alter table(:comments) do
      modify :commit_sha,
        references("commits", column: :sha, type: :string, on_delete: :delete_all),
        null: false
    end

    alter table(:comment_notifications) do
      modify :comment_id,
        references("comments", on_delete: :delete_all),
        from: references("comments"),
        null: false
    end
  end
end
