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

unless Application.get_env(:remit, :allow_seeding) do
  raise "Not allowed to seed!"
end

alias Remit.{Repo,Author,Commit}

Repo.delete_all Author
Repo.delete_all Commit

authors = (1..20) |> Enum.map(fn (i) ->
  name = Enum.random(["Fred", "Ada", "Enya", "Snorre", "Harry", "Maud"]) <> " " <> Enum.random(["Skog", "Lund", "Flod", "Träd", "Fisk"]) <> Enum.random(["berg", "kvist", "bäck", "zon", "plopp", "is"])

  Repo.insert! %Author{
    name: name,
    email: "user#{i}@example.com",
    username: "user#{i}",
  }
end)

(1..500) |> Enum.each(fn (i) ->
  sha = :crypto.hash(:sha, to_string(i)) |> Base.encode16 |> String.downcase
  timestamp = DateTime.utc_now() |> DateTime.add(-i, :second) |> DateTime.to_iso8601
  inserted_at = DateTime.utc_now() |> DateTime.add(-i * 60, :second) |> DateTime.truncate(:second)

  Repo.insert! %Commit{
    author_id: Enum.random(authors).id,
    sha: sha,
    payload: %{
      message: "Foo bar #{i}",
      timestamp: timestamp,
      url: "https://github.com/example/example/commit/#{sha}",
      repository: %{ name: "example" },
    },
    inserted_at: inserted_at,
  }
end)
