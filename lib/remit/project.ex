defmodule Remit.Project do
  @moduledoc false
  alias Remit.Repo
  alias Remit.{Commit, Team}
  import Ecto.Query, only: [from: 2, subquery: 1]

  def get_all do
    get_all_query()
    |> Repo.all()
    |> Enum.group_by(fn {commit, _} -> commit.repo end, fn {_, team} -> team end)
    |> Enum.map(fn {project, teams} -> if teams == [nil], do: {project, []}, else: {project, Enum.sort_by(teams, & &1.name)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp project_names_query, do: from c in Commit, select: [:repo], distinct: true

  defp get_all_query do
    from commit in subquery(project_names_query()),
      left_join: team in Team, on: commit.repo in team.projects,
      select: {commit, team}
  end
end
