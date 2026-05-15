# Seeds a handful of comment notifications addressed to a real GitHub username.
# Run with: mix fake.notifications YOUR_GITHUB_USERNAME

alias Remit.{Repo, Comment, CommentNotification, Commit}
import Ecto.Query

username = System.argv() |> List.first() || raise("Usage: mix fake.notifications YOUR_GITHUB_USERNAME")

commits = Repo.all(from c in Commit, limit: 5, order_by: [desc: c.inserted_at])

if commits == [] do
  raise "No commits in DB. Run `mix run priv/repo/seeds.exs` first."
end

commenters = ["foocat", "bardog", "hatwrangler", "frogcat", "bazmaster"]
bodies = [
  "Looks good! One minor nit: could we extract this into a helper?",
  "This might cause issues on the staging environment, worth double-checking.",
  "Nice one. Did you consider the edge case where the list is empty?",
  "I left a longer review on GitHub. TL;DR: approve with suggestions.",
  "Needs more cowbell.",
]

now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

count =
  commits
  |> Enum.with_index()
  |> Enum.reduce(0, fn {commit, i}, total ->
    commenter = Enum.at(commenters, rem(i, length(commenters)))
    body = Enum.at(bodies, rem(i, length(bodies)))

    comment =
      Repo.insert!(%Comment{
        github_id: Faker.number() * 1000 + i,
        commit_sha: commit.sha,
        body: body,
        commented_at: DateTime.add(now, -(i + 1) * 600, :second),
        commenter_username: commenter,
        path: nil,
        position: nil,
        payload: %{}
      })

    Repo.insert!(%CommentNotification{comment_id: comment.id, username: username})

    total + 1
  end)

IO.puts("Created #{count} comment notifications for @#{username}.")
IO.puts("Dev-login as \"#{username}\" in Settings to see them with a Resolve button.")
