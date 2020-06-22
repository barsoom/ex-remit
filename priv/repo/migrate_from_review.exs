# Script to migrate from https://github.com/barsoom/review
#
# Run this locally:
#
#     OLD_DB="postgres://…" NEW_DB="postgres://…" mix run priv/repo/migrate_from_review.exs

alias Remit.Utils

emails_to_usernames = %{
  # Example:
  # "foo@example.com" => "foo",
}

old_db_url = System.get_env("OLD_DB") || raise("Missing OLD_DB!")
new_db_url = System.get_env("NEW_DB") || raise("Missing NEW_DB!")

defmodule OldRepo do
  use Ecto.Repo,
    otp_app: :remit,
    adapter: Ecto.Adapters.Postgres,
    read_only: true
end

defmodule NewRepo do
  use Ecto.Repo,
    otp_app: :remit,
    adapter: Ecto.Adapters.Postgres
end

defmodule OldCommit do
  use Ecto.Schema

  schema "commits" do
    field :sha, :string
    field :reviewed_at, :utc_datetime
    belongs_to :reviewed_by_author, OldAuthor
  end
end

defmodule OldComment do
  use Ecto.Schema

  schema "comments" do
    field :github_id, :integer
    field :updated_at, :utc_datetime
  end
end

defmodule OldAuthor do
  use Ecto.Schema

  schema "authors" do
    field :name, :string
    field :email, :string
    field :username, :string
  end
end

import Ecto.Query

OldRepo.start_link(url: old_db_url, ssl: true)
NewRepo.start_link(url: new_db_url, ssl: true, timeout: :infinity)

# The old DB has a `review_started_by_author_id` but doesn't appear to have used it.
shas_in_new = NewRepo.all(from c in "commits", select: c.sha)
old_commits = OldRepo.all(
  from c in OldCommit,
    where: c.sha in ^shas_in_new and not is_nil(c.reviewed_at),
    preload: [:reviewed_by_author]
)

# The old DB has a `resolved_at` but doesn't appear to have used it.
gids_in_new = NewRepo.all(from c in "comments", select: c.github_id)
old_comments = OldRepo.all(
  from c in OldComment,
    where: c.github_id in ^gids_in_new and not is_nil(c.resolved_by_author_id)
)

missing_usernames =
  old_commits
  |> Enum.flat_map(fn
    %{reviewed_by_author: (%{username: nil, email: e} = a)} -> if emails_to_usernames[e], do: [], else: [a]
    _ -> []
  end)
  |> Enum.uniq()

if missing_usernames != [] do
  IO.puts "These reviewers are missing usernames! Add mappings to emails_to_usernames in the script and re-run it."
  IO.inspect missing_usernames
  exit(:shutdown)
end

NewRepo.transaction(fn ->
  # Set commits as reviewed.
  old_commits
  |> Enum.each(fn oc ->
    a = oc.reviewed_by_author
    reviewed_by_username = a && (a.username || emails_to_usernames[a.email])

    reviewed_at = oc.reviewed_at |> Utils.ensure_usec()

    # Review does not appear to have used `started_at` as expected, so we just set the same value for both.
    from(nc in Remit.Commit, where: nc.sha == ^oc.sha)
    |> NewRepo.update_all(set: [
      review_started_at: reviewed_at,
      review_started_by_username: reviewed_by_username,
      reviewed_at: reviewed_at,
      reviewed_by_username: reviewed_by_username,
    ])
  end)

  # Set comments as resolved.
  # Because Review doesn't notify each user separately, we mark it as resolved for *every* user in Remit, to match that.
  old_comments
  |> Enum.each(fn oc ->
    resolved_at = oc.updated_at |> Utils.ensure_usec()  # There is a `resolved_at` but it appears not to have been used.

    from(n in Remit.CommentNotification, join: nc in assoc(n, :comment), where: nc.github_id == ^oc.github_id)
    |> NewRepo.update_all(set: [resolved_at: resolved_at])
  end)
end)
