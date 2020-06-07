defmodule Remit.Repo.Migrations.DropCommitAuthorNames do
  use Ecto.Migration

  def change do
    alter table("commits") do
      remove :author_name, :string, null: false
    end
  end
end
