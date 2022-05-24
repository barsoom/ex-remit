defmodule Remit.Repo.Migrations.AddLowercaseUsernameCommentNotificationIndex do
  use Ecto.Migration

  def change do
    create index("comment_notifications", ["(lower(username))"],
             name: :comment_notifications_lower_username_index
           )
  end
end
