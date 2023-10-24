{opts, _, _} =
  OptionParser.parse(System.argv(),
    strict: [count: :integer, repo: :string, author: :string, co_author: [:string, :keep]]
  )

repo = opts |> Keyword.get(:repo, Faker.repo())
count = opts |> Keyword.get(:count, 5)
author = opts |> Keyword.get(:author, Faker.username())
co_authors = opts |> Keyword.get_values(:co_author)

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
            message: Faker.message_with_co_authors(Faker.message(), co_authors),
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

port =
  if System.get_env("DEVBOX") do
    45361
  else
    System.get_env("PORT") |> String.to_integer()
  end

# Using :httpc to avoid adding a dependency just for this.
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
|> IO.inspect()

IO.puts("Done!")
