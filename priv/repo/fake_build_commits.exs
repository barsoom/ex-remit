# Sends fake build/deploy commits that reference existing commit SHAs.
# These are the kind of commits created by a CD system when deploying a service
# (e.g. updating a k8s cluster's revision file).
# Usage: mix run priv/repo/fake_build_commits.exs [--repo stack] [--count 3]

{opts, _, _} =
  OptionParser.parse(System.argv(),
    strict: [count: :integer, repo: :string]
  )

import Ecto.Query

repo = Keyword.get(opts, :repo, "stack")
count = Keyword.get(opts, :count, 3)

port =
  if System.get_env("DEVBOX") do
    45361
  else
    System.get_env("PORT") |> String.to_integer()
  end

# Pick existing non-build commit SHAs to reference.
shas =
  Remit.Repo.all(
    from c in Remit.Commit,
      where: is_nil(c.deployed_sha),
      where: not is_nil(c.sha),
      order_by: [desc: c.id],
      select: c.sha,
      limit: ^count
  )

if shas == [] do
  IO.puts("No existing commits found. Run fake_webhook_commits.exs first.")
  System.halt(0)
end

IO.puts("Hi! Sending #{length(shas)} build commit(s) to the webhook…")
IO.puts("")

Enum.each(shas, fn sha ->
  message = "#{sha} Deploy to production"

  json =
    Jason.encode!(
      %{
        ref: "refs/heads/master",
        repository: %{
          master_branch: "master",
          name: repo,
          owner: %{name: "acme"}
        },
        commits: [
          %{
            author: %{email: "deploy@example.com", username: "deploy-bot[bot]"},
            committer: %{email: "deploy@example.com", username: "deploy-bot[bot]"},
            id: Faker.sha(),
            url: "https://example.com/",
            message: message,
            timestamp: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
          }
        ]
      },
      escape: :unicode_safe
    )
    |> String.to_charlist()

  IO.puts("  Deploying #{String.slice(sha, 0, 8)}… via #{repo}")

  :httpc.request(
    :post,
    {
      ~c"http://localhost:#{port}/webhooks/github?auth_key=dev",
      [{~c"x-github-event", ~c"push"}],
      ~c"application/json",
      json
    },
    [],
    []
  )
end)

IO.puts("")
IO.puts("Done!")
