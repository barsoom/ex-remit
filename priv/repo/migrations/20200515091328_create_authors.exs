defmodule Remit.Repo.Migrations.CreateAuthors do
  use Ecto.Migration

  def change do
    create table(:authors) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :username, :string, null: false

      timestamps([type: :utc_datetime])
    end
  end
end
