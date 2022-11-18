defmodule Remit.Team do
  @moduledoc false
  import Ecto.Query, only: [from: 2]
  use Remit, :schema
  alias Remit.Repo

  schema "teams" do
    field :slug, :string
    field :name, :string
    field :projects, {:array, :string}

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

    Remit.TeamProjects.reload()

    team
  end

  def add_project(%__MODULE__{projects: projects} = team, project) do
    team =
      team
      |> Ecto.Changeset.change(%{projects: [project | projects]})
      |> Repo.update!()

    Remit.TeamProjects.reload()

    team
  end

  def add_project(slug, project) when is_binary(slug) do
    get_by_slug(slug) |> add_project(project)
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
end
