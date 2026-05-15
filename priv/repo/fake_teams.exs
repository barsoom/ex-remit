# Seeds fake teams for development. Idempotent: wipes and re-creates on each run.
# Run with: mix fake.teams

alias Remit.Repo

Repo.delete_all(Remit.Team)

teams = [
  %{
    name: "Team Octopus",
    slug: "team-octopus",
    projects: ["catpics", "dogballads", "fishhacks"],
    usernames: ["foocat", "bardog", "bazmaster"]
  },
  %{
    name: "Team Cat",
    slug: "team-cat",
    projects: ["tigerleaks", "fishodes", "manpics"],
    usernames: ["hatwrangler", "frogcat"]
  },
  %{
    name: "Team Lion",
    slug: "team-lion",
    projects: ["powerhacks", "tikipics", "golden_leaks"],
    usernames: ["snakedog", "batcat", "foomaster"]
  }
]

for attrs <- teams do
  Repo.insert!(%Remit.Team{
    name: attrs.name,
    slug: attrs.slug,
    projects: attrs.projects,
    usernames: attrs.usernames
  })
end

Remit.Ownership.reload()

all_usernames = Enum.flat_map(teams, & &1.usernames)
IO.puts("Seeded #{length(teams)} teams.")
IO.puts("Dev login usernames (Settings > Dev login): #{Enum.join(all_usernames, ", ")}")
