defmodule RemitWeb.GithubWebhookController do
  use RemitWeb, :controller

  def create(conn, params) do
    handle_event(conn, event_name(conn), params)
  end

  # Private

  defp handle_event(conn, "ping", _params) do
    conn |> text("pong")
  end

  # Pushed commits.
  defp handle_event(conn, "push", params) do
    IO.puts "Received push:"
    IO.inspect(params)

    # TODO: Store in DB
    # TODO: Broadcast event

    conn |> text("Thanks!")
  end

  defp event_name(conn) do
    conn.req_headers
    |> Enum.into(%{})
    |> Map.fetch!("x-github-event")
  end
end
