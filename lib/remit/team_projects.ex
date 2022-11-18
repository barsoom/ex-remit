defmodule Remit.TeamProjects do
  @moduledoc """
  Cached state of project ownership to avoid hitting the DB.
  """
  use Agent

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    }
  end

  def start_link, do: Agent.start_link(&load_db_state/0, name: __MODULE__)

  def reload do
    Agent.update(__MODULE__, fn _ -> load_db_state() end)
    broadcast_change()
  end

  def claimed_by_team_or_unclaimed?(project, team)
  def claimed_by_team_or_unclaimed?(_, "all"), do: true
  def claimed_by_team_or_unclaimed?(project, team) do
    team_projects = get_state()
    project in team_projects[team] || !Enum.any?(team_projects, fn {_, projects} -> project in projects end)
  end

  def subscribe, do: Phoenix.PubSub.subscribe(Remit.PubSub, "projects")

  defp broadcast_change, do: Phoenix.PubSub.broadcast!(Remit.PubSub, "projects", :ownership_changed)

  defp get_state, do: Agent.get(__MODULE__, & &1)

  defp load_db_state do
    Remit.Team.get_all()
    |> Enum.reduce(%{}, & Map.put(&2, &1.slug, &1.projects))
  end
end
