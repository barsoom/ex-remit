defmodule Remit.Authorization do
  @moduledoc """
  Server-side authorization rules for review/comment actions. Used by
  `Remit.Tools`, `RemitWeb.CommitsLive` and `RemitWeb.CommentsLive`.

  Mirrors the rules the LiveViews use to render action buttons.
  """
  alias Remit.{Repo, Team, Commit, CommentNotification}
  import Ecto.Query

  def can_review_commit?(_action, %Commit{}, nil), do: false

  def can_review_commit?("start_review", %Commit{} = commit, username),
    do:
      is_nil(commit.reviewed_at) and is_nil(commit.review_started_at) and not Commit.authored_by?(commit, username) and
        can_review_repo?(teams_owning(commit.repo), username)

  # Lets the API review in one step; the UI gets there via start_review.
  def can_review_commit?("mark_reviewed", %Commit{} = commit, username),
    do:
      not Commit.authored_by?(commit, username) and
        (Commit.being_reviewed_by?(commit, username) or can_review_commit?("start_review", commit, username))

  def can_review_commit?("mark_unreviewed", %Commit{} = commit, username),
    do:
      Commit.being_reviewed_by?(commit, username) or
        (not is_nil(commit.reviewed_at) and not Commit.authored_by?(commit, username))

  def can_review_repo?(_owning_teams, nil), do: false
  def can_review_repo?([], _username), do: true

  def can_review_repo?(owning_teams, username),
    do: Enum.any?(owning_teams, &Team.user_can_review_projects?(&1, username))

  def can_resolve_notification?(_, nil), do: false

  def can_resolve_notification?(%CommentNotification{username: target}, username)
      when is_binary(username) and is_binary(target),
      do: String.downcase(target) == String.downcase(username)

  def can_resolve_notification?(%CommentNotification{}, _), do: false

  defp teams_owning(repo), do: Repo.all(from t in Team, where: ^repo in t.projects)
end
