count =
  case System.argv() do
    # Default
    [] -> 5
    [number_string | _] -> String.to_integer(number_string)
  end

shas = Remit.Commits.list_latest_shas(100)

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
