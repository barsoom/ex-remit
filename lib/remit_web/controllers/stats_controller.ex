defmodule RemitWeb.StatsController do
  use RemitWeb, :controller

  def show(conn, %{"max_commits_for_tests" => max_commits}), do: json(conn, Remit.Stats.compute(max_commits))
  def show(conn, _params), do: json(conn, Remit.Stats.compute())
end
