defmodule RemitWeb.CommitsLive do
  use RemitWeb, :live_view

  alias Remit.{Repo,Commit}
  import Ecto.Query

  # We subscribe on mount, and then when one client updates state, it broadcasts the new state to other clients.
  # Read more: https://elixirschool.com/blog/live-view-with-pub-sub/
  @broadcast_topic "commits"

  @impl true
  def mount(_params, _session, socket) do
    RemitWeb.Endpoint.subscribe(@broadcast_topic)

    socket = assign(socket, %{
      commits: get_commits(),
      unreviewed_count: unreviewed_count(),
    })

    # Flag `commits` as a "temporary assign" defaulting to `[]`.
    # This means we don't have to keep the full list of commits in memory: we just assign new or updated ones, and LiveView knows to replace or append/prepend them.
    # https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-dom-patching-and-temporary-assigns
    {:ok, socket, temporary_assigns: [commits: []]}
  end

  @impl true
  def handle_event("mark_reviewed", %{"cid" => commit_id}, socket) do
    # TODO: Allow useconds in DB so we don't need this dance
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    commit = Repo.get_by(Commit, id: commit_id) |> Ecto.Changeset.change(%{reviewed_at: now}) |> Repo.update!() |> Repo.preload(:author)

    new_assigns = %{ commits: [commit], unreviewed_count: unreviewed_count() }  # Only assign the new commit: see above about "temporary assigns".
    RemitWeb.Endpoint.broadcast_from(self(), @broadcast_topic, "_event_name", new_assigns)

    {:noreply, assign(socket, new_assigns)}
  end

  @impl true
  def handle_event("mark_unreviewed", %{"cid" => commit_id}, socket) do
    commit = Repo.get_by(Commit, id: commit_id) |> Ecto.Changeset.change(%{reviewed_at: nil}) |> Repo.update!() |> Repo.preload(:author)

    new_assigns = %{ commits: [commit], unreviewed_count: unreviewed_count() }  # Only assign the new commit: see above about "temporary assigns".
    RemitWeb.Endpoint.broadcast_from(self(), @broadcast_topic, "_event_name", new_assigns)

    {:noreply, assign(socket, new_assigns)}
  end

  # Receive broadcasts when other clients update their state.
  @impl true
  def handle_info(%{topic: @broadcast_topic, payload: new_assigns}, socket) do
    {:noreply, assign(socket, new_assigns)}
  end

  defp unreviewed_count do
    (from c in Commit, where: is_nil(c.reviewed_at)) |> Repo.aggregate(:count)
  end

  defp get_commits do
    Repo.all(
      from c in Commit,
        limit: 200,
        order_by: [desc: c.inserted_at],
        preload: :author
    )
  end
end
