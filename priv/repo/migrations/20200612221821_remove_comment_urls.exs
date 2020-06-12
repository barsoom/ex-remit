defmodule Remit.Repo.Migrations.RemoveCommentUrls do
  use Ecto.Migration

  def change do
    alter table("comments") do
      remove :url, :string
    end
  end
end
