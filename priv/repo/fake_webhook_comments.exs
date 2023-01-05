{opts, _, _} = OptionParser.parse(System.argv(), strict: [count: :integer, for_user: :string])

count = Keyword.get(opts, :count, 5)
for_user = Keyword.get(opts, :for_user, nil)

shas =
  if for_user != nil do
    commits =
      Remit.Commits.list_latest(100)
      |> Enum.filter(fn c -> Enum.member?(c.usernames, for_user) end)
      |> Enum.map(& &1.sha)

    # Elixir-ism, not sure if clean or not
    unless Enum.any?(commits) do
      IO.puts("Cannot find any commits by #{for_user}, you can generate some with 'mix wh.commits --author <username>'")

      exit(:shutdown)
    end

    commits
  else
    Remit.Commits.list_latest_shas(100)
  end

if shas == [] do
  IO.puts(:stderr, "Must have commits first!")
  exit(:shutdown)
end

IO.puts("Hi! Making #{count} comment webhook request#{unless count == 1, do: "s"}…")
IO.puts("")

1..count
|> Enum.each(fn _i ->
  sha = Enum.random(shas)

  json =
    Jason.encode!(
      %{
        action: "created",
        comment: %{
          id: Faker.number(),
          user: %{
            login: Faker.username()
          },
          commit_id: sha,
          position: nil,
          path: nil,
          created_at: "2016-01-25T08:41:25+01:00",
          body: Faker.comment()
        },
        repository: %{
          name: Faker.repo(),
          owner: %{login: "acme"}
        }
      },
      # Make Erlang happy.
      escape: :unicode_safe
    )
    |> String.to_charlist()

  # Using :httpc to avoid adding a dependency just for this.
  :httpc.request(
    :post,
    {
      'http://localhost:45361/webhooks/github?auth_key=dev',
      [{'x-github-event', 'commit_comment'}],
      'application/json',
      json
    },
    [],
    []
  )
  |> IO.inspect()
end)

IO.puts("Done!")
