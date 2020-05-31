count =
  case System.argv() do
    [] -> 5  # Default
    [number_string|_] -> String.to_integer(number_string)
  end

json = Jason.encode!(%{
  ref: "refs/heads/master",
  repository: %{
    master_branch: "master",
    name: Faker.repo(),
    owner: %{
      name: "acme",
    },
  },
  commits: (1..count) |> Enum.map(fn (_i) ->
    %{
      author: %{
        email: Faker.email(),
        name: Faker.human_name(),
      },
      id: Faker.sha(),
      url: "https://example.com/",
      message: Faker.message(),
      timestamp: (DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()),
    }
  end),
}, escape: :unicode_safe)  # Make Erlang happy.
|> String.to_charlist()

IO.puts "Hi! Sending #{count} commit#{unless count == 1, do: "s"} to the webhook…"
IO.puts("")

# Using :httpc to avoid adding a dependency just for this.
:httpc.request(
  :post,
  {
    'http://localhost:4000/webhooks/github?auth_key=dev',
    [{'x-github-event', 'push'}],
    'application/json',
    json,
  },
  [],
  []
)
|> IO.inspect()

IO.puts "Done!"
