defmodule Remit.TeamTest do
  use Remit.DataCase, async: true
  alias Remit.{Team, Factory}

  test "can list all teams" do
    Enum.each(1..3, fn _ -> Factory.insert!(:team) end)
    assert length(Team.get_all()) == 3
  end

  test "can create a new team" do
    Team.create("Best Team", "best-team", ["best-project"])
    assert Team.get_by_slug("best-team") != nil
  end

  test "it can list all projects for a team" do
    team = Factory.insert!(:team, projects: ["foo", "bar", "qux"])
    assert Team.projects_for(team.slug) == team.projects
  end

  test "it can add a project to a teams projects" do
    team = Factory.insert!(:team)
    Team.add_project(team.slug, "foo-project")

    assert Enum.member?(Team.projects_for(team.slug), "foo-project")
  end
end
