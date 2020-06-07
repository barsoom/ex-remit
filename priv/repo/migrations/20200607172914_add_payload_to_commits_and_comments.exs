defmodule Remit.Repo.Migrations.AddPayloadToCommitsAndComments do
  use Ecto.Migration

  def change do
    alter table("commits") do
      add :payload, :map
    end

    alter table("comments") do
      add :payload, :map
    end
  end
end
