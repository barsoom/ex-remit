defmodule RemitWeb.CLI.ToolController do
  @moduledoc """
  Thin REST shell over `Remit.Tools.call/3`. Behavior tests live against
  `Remit.Tools`; this layer is pure translation.
  """
  use RemitWeb, :controller

  def stats(conn, _params), do: respond(conn, "stats", %{})
  def list_commits(conn, params), do: respond(conn, "list_commits", params)
  def list_comments(conn, params), do: respond(conn, "list_comments", params)
  def list_teams(conn, params), do: respond(conn, "list_teams", params)
  def mark_reviewed(conn, %{"id" => id}), do: respond(conn, "mark_reviewed", %{"id" => id})
  def mark_unreviewed(conn, %{"id" => id}), do: respond(conn, "mark_unreviewed", %{"id" => id})
  def start_review(conn, %{"id" => id}), do: respond(conn, "start_review", %{"id" => id})
  def resolve_comment(conn, %{"id" => id}), do: respond(conn, "resolve_comment", %{"id" => id})
  def unresolve_comment(conn, %{"id" => id}), do: respond(conn, "unresolve_comment", %{"id" => id})

  defp respond(conn, tool, args) do
    ctx = %{username: conn.assigns.username, scopes: conn.assigns.scopes}

    case Remit.Tools.call(tool, args, ctx) do
      {:ok, payload} ->
        json(conn, payload)

      {:error, :insufficient_scope, msg} ->
        conn |> put_status(403) |> json(%{error: "insufficient_scope", message: msg})

      {:error, :forbidden, msg} ->
        conn |> put_status(403) |> json(%{error: "forbidden", message: msg})

      {:error, :unknown_tool, msg} ->
        conn |> put_status(404) |> json(%{error: "unknown_tool", message: msg})

      {:error, _, msg} ->
        conn |> put_status(400) |> json(%{error: msg})
    end
  end
end
