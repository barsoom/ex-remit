defmodule Remit.Repo.Migrations.DropSettingsTable do
  use Ecto.Migration

  def change do
    drop table("settings")
  end
end
