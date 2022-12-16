defmodule Remit.Team do
  @moduledoc false
  import Ecto.Query, only: [from: 2]
  use Remit, :schema
  require Logger
  alias Remit.Repo
  alias Remit.GitHubAPIClient

  schema "teams" do
    field :slug, :string
    field :name, :string
    field :projects, {:array, :string}
    field :usernames, {:array, :string}

    timestamps()
  end

  def get_by_slug(slug) do
    query =
      from t in Remit.Team,
        where: t.slug == ^slug

    Repo.one!(query)
  end

  def get_all do
    query =
      from Remit.Team,
        order_by: :slug

    Repo.all(query)
  end

  def create(name, slug, projects) do
    team = Repo.insert!(%__MODULE__{name: name, slug: slug, projects: projects})

    Remit.Ownership.reload()

    team
  end

  def add_project(%__MODULE__{projects: projects} = team, project) do
    team =
      team
      |> Ecto.Changeset.change(%{projects: [project | projects]})
      |> Repo.update!()

    Remit.Ownership.reload()

    team
  end

  def add_project(slug, project) when is_binary(slug) do
    get_by_slug(slug) |> add_project(project)
  end

  def update_from_github(token) do
    update_from_github(token, Remit.Config.github_org_slug())
  end

  defp update_from_github(token, org_slug)
  defp update_from_github(_, ""), do: false
  defp update_from_github(token, org_slug) do
    GitHubAPIClient.get_teams(token, org_slug)
    |> process_github_teams(token)
  end

  defp process_github_teams(%{"message" => error}, _) do
    Logger.error(error)
    false
  end
  defp process_github_teams(github_teams, token) when is_list(github_teams) do
    teams = get_all()

    github_teams
    |> Enum.filter(fn %{"slug" => slug} -> Enum.any?(teams, & &1.slug == slug) end)
    |> Enum.each(&update_team_members(&1, token))

    Remit.Ownership.reload()

    true
  end

  defp update_team_members(%{"slug" => slug, "url" => url}, token) do
    usernames = GitHubAPIClient.get_resource(token, url <> "/members")
      |> Enum.map(& &1["login"])

    q = from t in Remit.Team, where: t.slug == ^slug
    Repo.update_all(q, set: [usernames: usernames])
  end

  def claimed_projects do
    Repo.all(all_claimed_projects_query())
  end

  def all_claimed_projects_query do
    from Remit.Team,
      distinct: true,
      select: fragment("unnest(projects)")
  end

  def team_projects_query(slug) do
    from t in Remit.Team,
      select: fragment("unnest(projects)"),
      where: t.slug == ^slug
  end

  def team_members_query(slug) do
    from t in Remit.Team,
      select: t.usernames,
      where: t.slug == ^slug
  end
end
