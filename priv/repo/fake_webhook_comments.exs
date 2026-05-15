{opts, _, _} = OptionParser.parse(System.argv(), strict: [count: :integer, for_user: :string])

teams = Remit.Repo.all(Remit.Team)
all_usernames = if teams != [], do: Enum.flat_map(teams, & &1.usernames), else: nil

count = Keyword.get(opts, :count, 5)
for_user = Keyword.get(opts, :for_user, nil)

shas =
  if for_user != nil do
    commits =
      Remit.Commits.list_latest(100)
      |> Enum.filter(fn c -> Enum.member?(c.usernames, for_user) end)
      |> Enum.map(& &1.sha)

    if Enum.empty?(commits) do
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

started_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

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
            login: if(all_usernames, do: Enum.random(all_usernames), else: Faker.username())
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
      [{'x-github-event', 'commit_comment'}],
      'application/json',
      json
    },
    [],
    []
  )
  |> IO.inspect()
end)

import Ecto.Query

recent_notifications =
  Remit.Repo.all(
    from n in Remit.CommentNotification,
      where: n.inserted_at >= ^started_at
  )

resolved_count =
  Enum.reduce(recent_notifications, 0, fn notification, acc ->
    if Enum.random(0..1) == 1 do
      resolved_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)
      Remit.Repo.update_all(
        from(n in Remit.CommentNotification, where: n.id == ^notification.id),
        set: [resolved_at: resolved_at]
      )
      acc + 1
    else
      acc
    end
  end)

IO.puts("Resolved #{resolved_count}/#{length(recent_notifications)} notifications.")
IO.puts("Done!")
