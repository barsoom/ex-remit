defmodule RemitWeb.StatsController do
  use RemitWeb, :controller

  @max_commits Application.compile_env(:remit, :max_commits)

  def show(conn, params) do
    max_commits = params["max_commits_for_tests"] || @max_commits
    json(conn, Remit.Stats.compute(max_commits))
  end
end
