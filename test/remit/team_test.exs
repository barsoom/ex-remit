defmodule Remit.TeamTest do
  use Remit.DataCase, async: false
  alias Remit.{Team, Factory}

  test "can list all teams" do
    Enum.each(1..3, fn _ -> Factory.insert!(:team) end)
    assert length(Team.get_all()) == 3
  end

  test "can create a new team" do
    Team.create("Best Team", "best-team", ["best-project"])
    assert Team.get_by_slug("best-team") != nil
  end

  test "can list all projects for a team" do
    team = Factory.insert!(:team, projects: ["foo", "bar", "qux"])
    assert Team.get_by_slug(team.slug).projects == team.projects
  end

  test "can add a project to a team's projects" do
    team = Factory.insert!(:team)
    Team.add_project(team.slug, "foo-project")

    assert Enum.member?(Team.get_by_slug(team.slug).projects, "foo-project")
  end
end
