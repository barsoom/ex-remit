defmodule Remit.Authorization do
  @moduledoc """
  Server-side authorization rules for review/comment actions. Used by
  `Remit.Tools` and `RemitWeb.CommentsLive`.

  Mirrors the rules the LiveViews use to render action buttons.
  """
  alias Remit.{Repo, Team, Commit, CommentNotification}
  import Ecto.Query

  def can_review_commit?(_, nil), do: false

  def can_review_commit?(%Commit{} = commit, username) when is_binary(username) do
    cond do
      Commit.authored_by?(commit, username) -> false
      true -> on_owning_team?(commit.repo, username)
    end
  end

  defp on_owning_team?(repo, username) do
    case teams_owning(repo) do
      [] -> true
      teams -> Enum.any?(teams, &Team.user_can_review_projects?(&1, username))
    end
  end

  def can_resolve_notification?(_, nil), do: false

  def can_resolve_notification?(%CommentNotification{username: target}, username)
      when is_binary(username) and is_binary(target),
      do: String.downcase(target) == String.downcase(username)

  def can_resolve_notification?(%CommentNotification{}, _), do: false

  defp teams_owning(repo) do
    from(t in Team, where: ^repo in t.projects)
    |> Repo.all()
  end
end
