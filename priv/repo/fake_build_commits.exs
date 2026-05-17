# Sends fake build/deploy commits that reference existing commit SHAs.
# These are the kind of commits created by a CD system when deploying a service
# (e.g. updating a k8s cluster's revision file).
# Usage: mix run priv/repo/fake_build_commits.exs [--repo deploy-cluster] [--count 3]

{opts, _, _} =
  OptionParser.parse(System.argv(),
    strict: [count: :integer, repo: :string]
  )

import Ecto.Query

repos = if opts[:repo], do: [opts[:repo]], else: ["deploy-cluster", "auctionet"]
count = Keyword.get(opts, :count, 3)

# When using defaults, reserve extra SHAs for the named variants (multi-line, 8-digit).
extra_variants = if opts[:repo], do: 0, else: 2
total_needed = count + extra_variants

port =
  if System.get_env("DEVBOX") do
    45361
  else
    System.get_env("PORT") |> String.to_integer()
  end

already_deployed =
  Remit.Repo.all(from c in Remit.Commit, where: not is_nil(c.deployed_sha), select: c.deployed_sha)

shas =
  Remit.Repo.all(
    from c in Remit.Commit,
      where: is_nil(c.deployed_sha),
      where: not is_nil(c.sha),
      where: is_nil(c.reviewed_at),
      where: c.sha not in ^already_deployed,
      order_by: [desc: c.id],
      select: c.sha,
      limit: ^total_needed
  )

if shas == [] do
  IO.puts("No unreviewed undeployed commits found. Run fake_webhook_commits.exs first.")
  System.halt(0)
end

IO.puts("Hi! Sending build commit(s) to the webhook…")
IO.puts("")

post_webhook = fn json ->
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
end

build_commit_json = fn repo, message ->
  Jason.encode!(
    %{
      ref: "refs/heads/master",
      repository: %{master_branch: "master", name: repo, owner: %{name: "acme"}},
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
end

# Regular build commits: one SHA per repo (no cartesian product to avoid cross-repo duplicates).
loop_shas = Enum.take(shas, count)

for {repo, sha} <- Enum.zip(Stream.cycle(repos), loop_shas) do
  IO.puts("  Deploying #{String.slice(sha, 0, 8)}… via #{repo}")
  post_webhook.(build_commit_json.(repo, "#{sha} Deploy to production"))
end

if !opts[:repo] do
  # Multi-line build commit: 40-char SHA prefix + extra lines (must still be caught by build_commit?).
  if length(shas) > count do
    sha = Enum.at(shas, count)
    message = "#{sha} Deploy to production\n\nUpdated:\n- deploy-cluster/app-a/deployment.yaml\n- deploy-cluster/app-b/deployment.yaml"
    IO.puts("  Deploying #{String.slice(sha, 0, 8)}… via deploy-cluster (multi-line)")
    post_webhook.(build_commit_json.("deploy-cluster", message))
  end

  # 8-digit SHA in title: must NOT be caught by build_commit? and must be reviewable.
  short_sha = String.slice(Faker.sha(), 0, 8)
  IO.puts("  Sending short-sha deploy commit #{short_sha}… via deploy-cluster")
  post_webhook.(build_commit_json.("deploy-cluster", "#{short_sha} Deploy to production"))
end

IO.puts("")
IO.puts("Done!")
