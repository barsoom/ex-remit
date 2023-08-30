{opts, _, _} =
  OptionParser.parse(System.argv(), strict: [count: :integer, repo: :string, author: :string, co_authored: :boolean])

repo = opts |> Keyword.get(:repo, Faker.repo())
count = opts |> Keyword.get(:count, 5)
with_co_author? = opts |> Keyword.get(:co_authored, false)
author = opts |> Keyword.get(:author, Faker.username())

json =
  Jason.encode!(
    %{
      ref: "refs/heads/master",
      repository: %{
        master_branch: "master",
        name: repo,
        owner: %{
          name: "acme"
        }
      },
      commits:
        1..count
        |> Enum.map(fn _i ->
          %{
            author: %{
              email: Faker.email(),
              username: author
            },
            committer: %{
              email: Faker.email(),
              username: Faker.username()
            },
            id: Faker.sha(),
            url: "https://example.com/",
            message:
              if with_co_author? do
                authors = Enum.map(1..Enum.random(1..3), fn _i -> Faker.username() end)
                Faker.message_with_co_authors(Faker.message(), authors)
              else
                Faker.message()
              end,
            timestamp: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
          }
        end)
    },
    # Make Erlang happy.
    escape: :unicode_safe
  )
  |> String.to_charlist()

IO.puts("Hi! Sending #{count} commit#{unless count == 1, do: "s"} to the webhook…")
IO.puts("")

port = if System.get_env("DEVBOX") do
  45361
else
  System.get_env("PORT") |> String.to_integer()
end

# Using :httpc to avoid adding a dependency just for this.
:httpc.request(
  :post,
  {
    'http://localhost:#{port}/webhooks/github?auth_key=dev',
    [{'x-github-event', 'push'}],
    'application/json',
    json
  },
  [],
  []
)
|> IO.inspect()

IO.puts("Done!")
