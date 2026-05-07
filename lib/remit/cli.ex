defmodule Remit.CLI do
  @moduledoc """
  Escript entrypoint for `./remit`.

  Subcommands:
    remit login
    remit logout
    remit whoami
    remit stats
    remit commits list  [--author X --limit N]
    remit commits review <id>
    remit commits unreview <id>
    remit commits start-review <id>
    remit comments list  [--is unresolved|resolved|all] [--role all|for_me|by_me] [--limit N]
    remit comments resolve <id>
    remit comments unresolve <id>

  Global flags: --json (default human-readable; --json dumps the response).
  Exit codes: 0 success, 1 auth, 2 4xx, 3 5xx, 4 network error.
  """

  alias Remit.CLI.{Client, OAuth}

  # Matches the dev Phoenix port in config/dev.exs.
  @default_dev_port "45361"

  @top_help """
  remit — terminal CLI for Remit code review.

  Usage: remit [--base-url URL] [--json] <command> [args]

  Commands:
    login                       OAuth-authenticate this CLI (browser flow)
    logout                      Forget the saved token
    whoami                      Print the GitHub login of the current token
    stats                       Aggregate review stats
    commits                     List commits (alias for `commits list`)
    commits list  [--author X --limit N]
    commits review        <id|sha>  Mark commit reviewed
    commits unreview      <id|sha>  Reset review state
    commits start-review  <id|sha>  Mark "review in progress"
    comments                    List comment notifications (alias for `comments list`)
    comments list  [--is unresolved|resolved|all] [--role for_me|by_me|all] [--limit N]
    comments resolve      <id>  Resolve a comment notification
    comments unresolve    <id>  Unresolve a comment notification
    help                        Print this help
    <command> --help            Print help for a command

  Global flags:
    --json                      Output the raw JSON response (default: human-readable)
    --base-url URL              Override the server base URL (env: REMIT_URL)

  Environment:
    REMIT_URL                   Server base URL — only consulted by `login`.
                                Persisted in ~/.config/remit/credentials and
                                reused by all subsequent commands.
                                Default: http://localhost:#{@default_dev_port}

  Exit codes:
    0 success · 1 auth · 2 4xx · 3 5xx · 4 network error
  """

  @commits_help """
  Usage: remit commits <subcommand> [args]

  Subcommands:
    list  [--author USER --limit N]   List commits in the review feed
    review        <id|sha>            Mark commit reviewed
    unreview      <id|sha>            Reset review state
    start-review  <id|sha>            Mark "review in progress"

  <id|sha> can be the integer DB id (e.g. `4`) from `commits list`, or a
  SHA prefix of at least 4 hex chars (e.g. `4d3ed2d4`).

  Bare `remit commits` is shorthand for `remit commits list`.
  """

  @comments_help """
  Usage: remit comments <subcommand> [args]

  Subcommands:
    list  [--is unresolved|resolved|all] [--role for_me|by_me|all] [--limit N]
    resolve    <id>                   Resolve a comment notification
    unresolve  <id>                   Unresolve a comment notification

  Bare `remit comments` is shorthand for `remit comments list`.
  """

  def main(argv) do
    {flags, args, _} =
      OptionParser.parse(argv,
        switches: [
          json: :boolean,
          base_url: :string,
          author: :string,
          limit: :integer,
          is: :string,
          role: :string,
          help: :boolean
        ],
        aliases: [j: :json, h: :help]
      )

    flags_map = Enum.into(flags, %{})
    base_url = flags_map[:base_url] || System.get_env("REMIT_URL") || default_base_url()

    try do
      dispatch(args, flags_map, base_url)
    rescue
      e in [RuntimeError] ->
        IO.puts(:stderr, e.message)
        System.halt(1)
    end
  end

  # Public so the test suite can exercise parsing.
  def parse(argv) do
    {flags, args, _} =
      OptionParser.parse(argv,
        switches: [json: :boolean, base_url: :string, author: :string, limit: :integer, is: :string, role: :string],
        aliases: [j: :json]
      )

    {args, Enum.into(flags, %{})}
  end

  # Private

  # Top-level / subcommand help.
  defp dispatch([], _flags, _base_url), do: IO.puts(@top_help)
  defp dispatch(["help"], _flags, _base_url), do: IO.puts(@top_help)
  defp dispatch(["commits", "help"], _flags, _base_url), do: IO.puts(@commits_help)
  defp dispatch(["comments", "help"], _flags, _base_url), do: IO.puts(@comments_help)

  defp dispatch(args, %{help: true}, _base_url) do
    case args do
      ["commits" | _] -> IO.puts(@commits_help)
      ["comments" | _] -> IO.puts(@comments_help)
      _ -> IO.puts(@top_help)
    end
  end

  defp dispatch(["login"], _flags, base_url) do
    creds = OAuth.login!(base_url)
    Client.save_credentials!(creds)

    case Client.request!(:get, "/api/cli/whoami") do
      {200, %{"username" => login}} -> IO.puts("Logged in as #{login}.")
      _ -> IO.puts(:stderr, "Logged in but whoami failed.")
    end
  end

  defp dispatch(["logout"], _flags, _base_url) do
    Client.delete_credentials!()
    IO.puts("Logged out.")
  end

  defp dispatch(["whoami"], flags, _base_url) do
    request_and_render(:get, "/api/cli/whoami", nil, flags, &render_whoami/1)
  end

  defp dispatch(["stats"], flags, _base_url) do
    request_and_render(:get, "/api/cli/stats", nil, flags, &render_stats/1)
  end

  defp dispatch(["commits"], flags, base_url), do: dispatch(["commits", "list"], flags, base_url)

  defp dispatch(["commits", "list"], flags, _base_url) do
    query =
      Enum.reject(
        [{:author, flags[:author]}, {:limit, flags[:limit]}],
        fn {_, v} -> is_nil(v) end
      )

    qs = if query == [], do: "", else: "?" <> URI.encode_query(query)
    request_and_render(:get, "/api/cli/commits" <> qs, nil, flags, &render_commits/1)
  end

  defp dispatch(["commits", verb, id], flags, _base_url)
       when verb in ["review", "unreview", "start-review"] do
    id = require_id_or_sha!(id, "commit")

    path =
      case verb do
        "review" -> "/api/cli/commits/#{id}/review"
        "unreview" -> "/api/cli/commits/#{id}/unreview"
        "start-review" -> "/api/cli/commits/#{id}/start_review"
      end

    request_and_render(:post, path, nil, flags, &render_commit/1)
  end

  defp dispatch(["comments"], flags, base_url), do: dispatch(["comments", "list"], flags, base_url)

  defp dispatch(["comments", "list"], flags, _base_url) do
    query =
      [
        {:resolved_filter, flags[:is]},
        {:user_filter, flags[:role]},
        {:limit, flags[:limit]}
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    qs = if query == [], do: "", else: "?" <> URI.encode_query(query)
    request_and_render(:get, "/api/cli/comments" <> qs, nil, flags, &render_comments/1)
  end

  defp dispatch(["comments", verb, id], flags, _base_url) when verb in ["resolve", "unresolve"] do
    id = require_numeric_id!(id, "comment notification")
    path = "/api/cli/comments/#{id}/#{verb}"
    request_and_render(:post, path, nil, flags, &render_comment/1)
  end

  defp dispatch(other, _flags, _base_url) do
    IO.puts(:stderr, "Unknown command: #{Enum.join(other, " ")}\n")
    IO.puts(:stderr, @top_help)
    System.halt(2)
  end

  defp require_numeric_id!(id, kind) do
    case Integer.parse(id) do
      {n, ""} ->
        n

      _ ->
        IO.puts(:stderr, "Expected a numeric #{kind} id (the `ID` column from `remit comments list`), got: #{id}")
        System.halt(2)
    end
  end

  defp require_id_or_sha!(id, kind) do
    cond do
      Regex.match?(~r/^\d+$/, id) -> id
      Regex.match?(~r/^[0-9a-fA-F]{4,40}$/, id) -> id
      true ->
        IO.puts(:stderr, "Expected a numeric #{kind} id or a SHA prefix (≥4 hex chars), got: #{id}")
        System.halt(2)
    end
  end

  defp default_base_url do
    "http://localhost:" <> System.get_env("PORT", @default_dev_port)
  end

  defp request_and_render(method, path, body, flags, renderer) do
    case Client.request!(method, path, body) do
      {status, payload} when status in 200..299 ->
        if flags[:json], do: IO.puts(Jason.encode!(payload)), else: renderer.(payload)

      {401, _} ->
        IO.puts(:stderr, "Auth failure (run `./remit login`).")
        System.halt(1)

      {status, payload} when status >= 400 and status < 500 ->
        IO.puts(:stderr, "Client error (#{status}): #{inspect(payload)}")
        System.halt(2)

      {status, payload} when status >= 500 ->
        IO.puts(:stderr, "Server error (#{status}): #{inspect(payload)}")
        System.halt(3)

      {:error, reason} ->
        IO.puts(:stderr, "Network error: #{inspect(reason)}")
        System.halt(4)
    end
  end

  defp render_whoami(%{"username" => login}), do: IO.puts(login)

  defp render_stats(stats) do
    for {k, v} <- stats, do: :io.format("~-50ts ~ts~n", [to_string(k), inspect(v)])
  end

  defp render_commits(commits) do
    :io.format("~-6ts ~-9ts ~-30ts ~-12ts ~ts~n", ["ID", "SHA", "REPO", "REVIEWED", "MESSAGE"])

    for c <- commits do
      :io.format(
        "~-6ts ~-9ts ~-30ts ~-12ts ~ts~n",
        [
          to_string(c["id"]),
          c["short_sha"] || "",
          truncate(c["repo"] || "", 30),
          if(c["reviewed_at"], do: "yes", else: "no"),
          truncate(c["message_summary"] || "", 80)
        ]
      )
    end
  end

  defp render_commit(c),
    do:
      :io.format("commit ~ts ~ts (#~ts) reviewed=~ts~n", [
        c["short_sha"],
        c["repo"],
        to_string(c["id"]),
        if(c["reviewed_at"], do: "yes", else: "no")
      ])

  defp render_comments(comments) do
    :io.format("~-6ts ~-12ts ~-12ts ~ts~n", ["ID", "FOR", "BY", "BODY"])

    for n <- comments do
      :io.format(
        "~-6ts ~-12ts ~-12ts ~ts~n",
        [
          to_string(n["id"]),
          truncate(n["username"] || "", 12),
          truncate(get_in(n, ["comment", "commenter_username"]) || "", 12),
          truncate(get_in(n, ["comment", "body"]) || "", 80)
        ]
      )
    end
  end

  defp render_comment(n),
    do:
      :io.format("comment notification ~ts (for ~ts) resolved=~ts~n", [
        to_string(n["id"]),
        n["username"],
        if(n["resolved_at"], do: "yes", else: "no")
      ])

  defp truncate(s, n) when byte_size(s) <= n, do: s
  defp truncate(s, n), do: String.slice(s, 0, n - 1) <> "…"
end
