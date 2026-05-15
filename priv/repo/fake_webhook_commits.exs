{opts, _, _} =
  OptionParser.parse(System.argv(),
    strict: [count: :integer, repo: :string, author: :string, co_author: [:string, :keep]]
  )

teams = Remit.Repo.all(Remit.Team)
co_authors = opts |> Keyword.get_values(:co_author)

port =
  if System.get_env("DEVBOX") do
    45361
  else
    System.get_env("PORT") |> String.to_integer()
  end

send_commits = fn repo, author, count ->
  json =
    Jason.encode!(
      %{
        ref: "refs/heads/master",
        repository: %{
          master_branch: "master",
          name: repo,
          owner: %{name: "acme"}
        },
        commits:
          1..count
          |> Enum.map(fn _i ->
            %{
              author: %{email: Faker.email(), username: author},
              committer: %{email: Faker.email(), username: Faker.username()},
              id: Faker.sha(),
              url: "https://example.com/",
              message: Faker.message_with_co_authors(Faker.message(), co_authors),
              timestamp: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
            }
          end)
      },
      escape: :unicode_safe
    )
    |> String.to_charlist()

  IO.puts("  Sending #{count} commit#{unless count == 1, do: "s"} by #{author} on #{repo}…")

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

IO.puts("Hi! Sending commits to the webhook…")
IO.puts("")

if opts[:repo] || opts[:author] do
  repo = Keyword.get(opts, :repo, Faker.repo())
  author = Keyword.get(opts, :author, Faker.username())
  count = Keyword.get(opts, :count, 5)
  send_commits.(repo, author, count)
else
  batches =
    if teams != [] do
      Enum.map(teams, fn team ->
        count = Keyword.get(opts, :count, Enum.random(1..5))
        {Enum.random(team.projects), Enum.random(team.usernames), count}
      end)
    else
      [{Faker.repo(), Faker.username(), Keyword.get(opts, :count, 5)}]
    end

  Enum.each(batches, fn {repo, author, count} -> send_commits.(repo, author, count) end)
end

IO.puts("")
IO.puts("Done!")
