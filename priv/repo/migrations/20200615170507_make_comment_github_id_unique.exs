defmodule Remit.Repo.Migrations.MakeCommentGithubIdUnique do
  use Ecto.Migration

  def change do
    create unique_index(:comments, [:github_id])
  end
end
