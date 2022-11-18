defmodule ParseArgs do
  @default_count 5

  def count(args) do
    case args do
      [] ->
        @default_count

      [number_string | _] ->
        case Integer.parse(number_string) do
          {number, ""} -> number
          _ -> @default_count
        end
    end
  end

  def repo(args)
  def repo(["--repo", repo | _]), do: repo
  def repo([]), do: nil
  def repo([_ | tail]), do: repo(tail)

  def with_co_author?(args), do: Enum.member?(args, "--co-authored")
end

repo = ParseArgs.repo(System.argv()) || Faker.repo()
count = ParseArgs.count(System.argv())
with_co_author? = ParseArgs.with_co_author?(System.argv())

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
              username: Faker.username()
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

# Using :httpc to avoid adding a dependency just for this.
:httpc.request(
  :post,
  {
    'http://localhost:45361/webhooks/github?auth_key=dev',
    [{'x-github-event', 'push'}],
    'application/json',
    json
  },
  [],
  []
)
|> IO.inspect()

IO.puts("Done!")
