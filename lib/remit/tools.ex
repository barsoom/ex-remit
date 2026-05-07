defmodule Remit.Tools do
  @moduledoc """
  Tool registry shared by `/mcp` (JSON-RPC) and `/api/cli/*` (REST).

  `call/3` is the single entry point; it enforces scope and validates arguments
  before dispatching to a per-tool head. Both controllers must go through it.
  """
  alias Remit.{Commits, Comments, Authorization, Stats, Team, Repo}
  alias Remit.{Commit, CommentNotification}
  import Ecto.Query

  @max_commits Application.compile_env(:remit, :max_commits)
  @max_comments Application.compile_env(:remit, :max_comments)

  @commit_id_schema %{
    type: "object",
    properties: %{
      id: %{
        description: "Either the Remit commit DB id (integer) or a SHA prefix (at least 4 hex chars).",
        oneOf: [%{type: "integer"}, %{type: "string"}]
      }
    },
    required: ["id"],
    additionalProperties: false
  }

  def list do
    [
      %{
        name: "stats",
        description:
          "Aggregate review stats: unreviewed_count, reviewable_count, oldest_unreviewed_in_seconds, recent_reviews.",
        scopes: ["remit:read"],
        input_schema: %{
          type: "object",
          properties: %{},
          additionalProperties: false
        }
      },
      %{
        name: "list_commits",
        description:
          "List the latest commits in the review feed (unreviewed first, then reviewed within the cutoff window).",
        scopes: ["remit:read"],
        input_schema: %{
          type: "object",
          properties: %{
            author: %{type: "string", description: "Filter by GitHub author username."},
            repo: %{type: "string", description: "Filter by exact repo name."},
            projects_of_team: %{type: "string", description: "Team slug; includes any unclaimed repo too."},
            members_of_team: %{type: "string", description: "Team slug; matches commits with any author in that team."},
            status: %{
              type: "string",
              enum: ["unreviewed", "reviewed", "all"],
              description: "Defaults to 'all' (unreviewed first, then reviewed within the cutoff)."
            },
            limit: %{type: "integer", minimum: 1, maximum: @max_commits}
          },
          additionalProperties: false
        }
      },
      %{
        name: "list_comments",
        description:
          "List comment notifications. Defaults to unresolved notifications addressed to the authenticated user.",
        scopes: ["remit:read"],
        input_schema: %{
          type: "object",
          properties: %{
            resolved_filter: %{type: "string", enum: ["unresolved", "resolved", "all"]},
            user_filter: %{type: "string", enum: ["for_me", "by_me", "all"]},
            repo: %{type: "string", description: "Filter to notifications whose commit is in this repo."},
            limit: %{type: "integer", minimum: 1, maximum: @max_comments}
          },
          additionalProperties: false
        }
      },
      %{
        name: "start_review",
        description: "Mark the commit as 'review in progress' by the authenticated user.",
        scopes: ["remit:review"],
        input_schema: @commit_id_schema
      },
      %{
        name: "mark_reviewed",
        description: "Mark the commit as reviewed by the authenticated user.",
        scopes: ["remit:review"],
        input_schema: @commit_id_schema
      },
      %{
        name: "mark_unreviewed",
        description: "Reset the commit's review state (review_started_at and reviewed_at cleared).",
        scopes: ["remit:review"],
        input_schema: @commit_id_schema
      },
      %{
        name: "list_teams",
        description:
          "List teams with their slug, name, projects, members, and review_access. " <>
            "Note that a user can also review commits in any repo that no team has claimed.",
        scopes: ["remit:read"],
        input_schema: %{
          type: "object",
          properties: %{
            slug: %{type: "string", description: "Exact-match team slug."},
            member: %{
              type: "string",
              description: "Case-insensitive GitHub username; matches teams that include this user."
            },
            project: %{
              type: "string",
              description: "Exact-match project (repo) name; matches teams that own this project."
            }
          },
          additionalProperties: false
        }
      },
      %{
        name: "resolve_comment",
        description: "Resolve a comment notification by its DB id.",
        scopes: ["remit:review"],
        input_schema: %{
          type: "object",
          properties: %{id: %{type: "integer", description: "Remit comment_notification DB id."}},
          required: ["id"],
          additionalProperties: false
        }
      },
      %{
        name: "unresolve_comment",
        description: "Unresolve a previously-resolved comment notification by its DB id.",
        scopes: ["remit:review"],
        input_schema: %{
          type: "object",
          properties: %{id: %{type: "integer", description: "Remit comment_notification DB id."}},
          required: ["id"],
          additionalProperties: false
        }
      }
    ]
  end

  @doc """
  Single entry point. Enforces required scope and enum arguments before dispatching.

  `ctx` is `%{username: binary, scopes: [binary]}`.
  """
  def call(name, args, ctx) do
    case Enum.find(list(), &(&1.name == name)) do
      nil ->
        {:error, :unknown_tool, "unknown tool: #{name}"}

      %{scopes: required} = tool ->
        cond do
          not Enum.any?(required, &(&1 in ctx.scopes)) ->
            {:error, :insufficient_scope, "token missing required scope (need one of: #{Enum.join(required, ", ")})"}

          error = invalid_enum_arg(tool.input_schema, args) ->
            error

          true ->
            do_call(name, args, ctx)
        end
    end
  end

  defp invalid_enum_arg(%{properties: properties}, args) do
    Enum.find_value(properties, fn
      {key, %{enum: allowed}} ->
        value = Map.get(args, Atom.to_string(key))

        if value != nil and value not in allowed,
          do: {:error, :bad_request, "#{key} must be one of #{Enum.join(allowed, ", ")}, got #{inspect(value)}"}

      _ ->
        nil
    end)
  end

  defp commit_payload(%Commit{} = c) do
    %{
      id: c.id,
      sha: c.sha,
      short_sha: short_sha(c.sha),
      owner: c.owner,
      repo: c.repo,
      url: c.url,
      message: c.message,
      message_summary: Commit.message_summary(c),
      usernames: c.usernames,
      committed_at: c.committed_at,
      review_started_at: c.review_started_at,
      review_started_by_username: c.review_started_by_username,
      reviewed_at: c.reviewed_at,
      reviewed_by_username: c.reviewed_by_username
    }
  end

  defp comment_payload(%CommentNotification{} = n) do
    %{
      id: n.id,
      username: n.username,
      resolved_at: n.resolved_at,
      comment: %{
        id: n.comment.id,
        body: n.comment.body,
        path: n.comment.path,
        position: n.comment.position,
        commenter_username: n.comment.commenter_username,
        commented_at: n.comment.commented_at
      },
      commit: commit_summary(n.comment.commit)
    }
  end

  defp do_call("stats", _, _ctx), do: {:ok, Stats.compute()}

  defp do_call("list_commits", args, _ctx) do
    with {:ok, limit} <- coerce_limit(args, @max_commits) do
      {:ok, args |> build_commit_filters() |> Commits.list_latest(limit) |> Enum.map(&commit_payload/1)}
    end
  end

  defp do_call("list_comments", args, ctx) do
    with {:ok, limit} <- coerce_limit(args, @max_comments) do
      opts =
        [
          username: ctx.username,
          resolved_filter: Map.get(args, "resolved_filter", "unresolved"),
          user_filter: Map.get(args, "user_filter", "for_me"),
          limit: limit
        ]
        |> maybe_put(:repo, Map.get(args, "repo"))

      {:ok, Comments.list_notifications(opts) |> Enum.map(&comment_payload/1)}
    end
  end

  defp do_call("list_teams", args, _ctx) do
    slug = Map.get(args, "slug")
    member = Map.get(args, "member")
    project = Map.get(args, "project")

    teams =
      Team.get_all()
      |> Enum.filter(&team_matches?(&1, slug, member, project))
      |> Enum.map(&team_payload/1)

    {:ok, teams}
  end

  defp do_call(action, %{"id" => id}, ctx)
       when action in ~w(start_review mark_reviewed mark_unreviewed) do
    case resolve_commit(id) do
      {:ok, commit} ->
        case Commits.review_action(action, commit.id, ctx.username) do
          {:ok, updated} ->
            Commits.broadcast_changed_commit(updated)
            {:ok, commit_payload(updated)}

          {:error, :denied} ->
            {:error, :forbidden,
             "#{action} is not allowed: the commit is yours, someone else is reviewing it, " <>
               "its review state doesn't allow it, or its project is owned by a team you're not on"}
        end

      {:error, :ambiguous, prefix} ->
        {:error, :bad_request, "ambiguous SHA prefix '#{prefix}', provide more characters"}

      {:error, :not_found, prefix} ->
        {:error, :bad_request, "no commit found with SHA starting with '#{prefix}'"}

      {:error, :bad_request, msg} ->
        {:error, :bad_request, msg}
    end
  end

  defp do_call("resolve_comment", %{"id" => id}, ctx),
    do: resolve_or_unresolve(id, ctx, &Comments.resolve/1)

  defp do_call("unresolve_comment", %{"id" => id}, ctx),
    do: resolve_or_unresolve(id, ctx, &Comments.unresolve/1)

  defp do_call(_action, _args, _ctx), do: {:error, :bad_request, "missing required argument: id"}

  defp resolve_or_unresolve(id_arg, ctx, action) do
    with {:ok, id} <- coerce_id(id_arg),
         %CommentNotification{} = notification <- Repo.get(CommentNotification, id),
         true <- Authorization.can_resolve_notification?(notification, ctx.username) do
      {:ok,
       id
       |> action.()
       |> Repo.preload(comment: :commit)
       |> comment_payload()}
    else
      nil ->
        {:error, :bad_request, "no comment_notification found with id #{inspect(id_arg)}"}

      false ->
        {:error, :forbidden, "comment notification is not addressed to you"}

      {:error, code, msg} ->
        {:error, code, msg}
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp team_matches?(team, slug, member, project) do
    matches_slug?(team, slug) && matches_member?(team, member) && matches_project?(team, project)
  end

  defp matches_slug?(_team, nil), do: true
  defp matches_slug?(_team, ""), do: true
  defp matches_slug?(team, slug), do: team.slug == slug

  defp matches_member?(_team, nil), do: true
  defp matches_member?(_team, ""), do: true

  defp matches_member?(team, member) do
    down = String.downcase(member)
    Enum.any?(team.usernames, &(String.downcase(&1) == down))
  end

  defp matches_project?(_team, nil), do: true
  defp matches_project?(_team, ""), do: true
  defp matches_project?(team, project), do: project in team.projects

  defp team_payload(%Team{} = t) do
    %{
      slug: t.slug,
      name: t.name,
      projects: t.projects,
      usernames: t.usernames,
      review_access: Atom.to_string(t.review_access)
    }
  end

  defp build_commit_filters(args) do
    [
      author: "author",
      repos: "repo",
      projects_of_team: "projects_of_team",
      members_of_team: "members_of_team",
      reviewed: "status"
    ]
    |> Enum.reduce([], fn {filter, key}, acc ->
      case Map.get(args, key) do
        nil -> acc
        "" -> acc
        value when filter == :repos -> [{filter, [value]} | acc]
        value -> [{filter, value} | acc]
      end
    end)
  end

  defp coerce_limit(args, max) do
    case Map.get(args, "limit") do
      nil ->
        {:ok, max}

      n when is_integer(n) ->
        check_limit(n, max)

      s when is_binary(s) ->
        case Integer.parse(s) do
          {n, ""} -> check_limit(n, max)
          _ -> {:error, :bad_request, "limit must be an integer, got #{inspect(s)}"}
        end

      other ->
        {:error, :bad_request, "limit must be an integer, got #{inspect(other)}"}
    end
  end

  defp check_limit(n, max) when n >= 1, do: {:ok, min(n, max)}
  defp check_limit(n, _max), do: {:error, :bad_request, "limit must be at least 1, got #{n}"}

  defp coerce_id(id) when is_integer(id), do: {:ok, id}

  defp coerce_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> {:ok, n}
      _ -> {:error, :bad_request, "id must be an integer, got #{inspect(id)}"}
    end
  end

  defp coerce_id(other),
    do: {:error, :bad_request, "id must be an integer, got #{inspect(other)}"}

  # Misses are :bad_request rather than raised so user typos don't reach Sentry.
  defp resolve_commit(id) when is_integer(id), do: get_commit(id)

  defp resolve_commit(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> get_commit(n)
      _ -> resolve_commit_by_sha(id)
    end
  end

  defp get_commit(id) do
    case Repo.get(Commit, id) do
      nil -> {:error, :bad_request, "no commit found with id #{id}"}
      commit -> {:ok, commit}
    end
  end

  defp resolve_commit_by_sha(prefix) do
    if hex_prefix?(prefix) do
      case Repo.all(from c in Commit, where: like(c.sha, ^(prefix <> "%")), limit: 2) do
        [commit] -> {:ok, commit}
        [] -> {:error, :not_found, prefix}
        [_, _ | _] -> {:error, :ambiguous, prefix}
      end
    else
      {:error, :not_found, prefix}
    end
  end

  defp hex_prefix?(s), do: Regex.match?(~r/^[0-9a-fA-F]{4,40}$/, s)

  defp short_sha(sha), do: String.slice(sha, 0, 8)

  defp commit_summary(nil), do: nil

  defp commit_summary(%Commit{} = c) do
    %{
      id: c.id,
      short_sha: short_sha(c.sha),
      repo: c.repo,
      owner: c.owner,
      url: c.url
    }
  end
end
