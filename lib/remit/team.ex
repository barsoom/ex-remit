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

  def projects_for(team_slug) do
    get_by_slug(team_slug).projects
  end

  def create(name, slug, projects) do
    Repo.insert!(%__MODULE__{name: name, slug: slug, projects: projects})
  end

  def add_project(%__MODULE__{projects: projects} = team, project) do
    team
    |> Ecto.Changeset.change(%{projects: [project | projects]})
    |> Repo.update!()
  end

  def add_project(slug, project) when is_binary(slug) do
    get_by_slug(slug) |> add_project(project)
  end
end
