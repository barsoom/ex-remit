# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Remit.Repo.insert!(%Remit.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

unless Application.get_env(:remit, :allow_seeding) || System.get_env("ALLOW_SEEDING") do
  raise "Not allowed to seed!"
end

alias Remit.{Repo, Commit}

Repo.delete_all(Commit)

1..500
|> Enum.each(fn i ->
  sha = Faker.sha(i)
  committed_at = DateTime.utc_now() |> DateTime.add(-i, :second) |> DateTime.truncate(:second)
  inserted_at = DateTime.utc_now() |> DateTime.add(-i * 60, :second) |> DateTime.truncate(:second)

  Repo.insert!(%Commit{
    sha: sha,
    author_email: Faker.email(i),
    author_name: Faker.human_name(),
    author_usernames: (1..Enum.random(1..2)) |> Enum.map(fn (_) -> Faker.username() end),
    owner: "acme",
    repo: Faker.repo(),
    message: Faker.message(),
    committed_at: committed_at,
    inserted_at: inserted_at,
  })
end)
