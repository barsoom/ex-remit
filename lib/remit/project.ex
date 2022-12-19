defmodule Remit.Project do
  @moduledoc false
  alias Remit.Repo
  alias Remit.{Commit, Team}
  import Ecto.Query, only: [from: 2, subquery: 1]

  def get_all do
    get_all_query()
    |> Repo.all()
    |> Enum.group_by(fn {commit, _} -> commit.repo end, fn {_, team} -> team end)
    |> Enum.map(fn {project, teams} = element -> if teams == [nil], do: {project, []}, else: element end)
  end

  defp project_names_query, do: from c in Commit, select: [:repo], distinct: true

  defp get_all_query do
    from commit in subquery(project_names_query()),
      left_join: team in Team, on: commit.repo in team.projects,
      select: {commit, team},
      order_by: {:asc, commit.repo}
  end
end
