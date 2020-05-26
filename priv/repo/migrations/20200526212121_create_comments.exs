defmodule Remit.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create index(:commits, [:sha])

    create table(:comments) do
      add :github_id, :integer, null: false
      add :commit_sha, :string, null: false
      add :body, :text, null: false
      add :commented_at, :utc_datetime, null: false
      add :commenter_username, :string, null: false

      # The file path, like "foo/bar.ex", if it was a line comment.
      add :path, :text

      # The line of the diff for this file that was commented on. Or NULL if it's not a line comment.
      add :position, :integer

      timestamps(type: :utc_datetime)
    end
    create index(:comments, [:commit_sha])

    create table(:comment_notifications) do
      add :comment_id, references(:comments), null: false
      add :resolved_at, :utc_datetime
      add :commenter_username, :string
      add :committer_name, :string

      timestamps(type: :utc_datetime)
    end
    create constraint(:comment_notifications, "has_username_or_name", check: "commenter_username IS NOT NULL OR committer_name IS NOT NULL")
  end
end
