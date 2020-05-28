json = Jason.encode!(%{
  ref: "refs/heads/master",
  repository: %{
    master_branch: "master",
    name: Faker.repo(),
    owner: %{
      name: "acme",
    },
  },
  commits: [
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
  ],
}, escape: :unicode_safe)  # Make Erlang happy.
|> IO.inspect()
|> String.to_charlist()

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
