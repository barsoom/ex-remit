defmodule RemitWeb.GithubWebhookController do
  use RemitWeb, :controller

  def create(conn, params) do
    event_name =
      conn.req_headers
      |> Enum.into(%{})
      |> Map.fetch!("x-github-event")

    Honeybadger.add_breadcrumb("Webhook received", metadata: %{
      event_name: event_name,
      params: params,
    })

    handle_event(conn, event_name, params)
  end

  # Private

  defp handle_event(conn, "ping", _params) do
    conn |> text("pong")
  end

  # Pushed commits.
  defp handle_event(conn, "push", params) do
    Remit.IngestCommits.from_params(params)

    conn |> text("Thanks!")
  end

  # Commit comment.
  defp handle_event(conn, "commit_comment", params) do
    Remit.IngestComment.from_params(params)

    conn |> text("Thanks!")
  end
end
