defmodule Remit.Repo.Migrations.RenameAuthorUsernamesToUsernames do
  use Ecto.Migration

  def change do
    rename table("commits"), :author_usernames, to: :usernames
  end
end
