defmodule Remit.Repo.Migrations.AddMoreIndexesStill do
  use Ecto.Migration

  def change do
    create index(:comments, ["lower(commenter_username)"], name: :comments_lower_username_index)
  end
end
