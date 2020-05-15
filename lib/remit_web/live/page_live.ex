defmodule RemitWeb.PageLive do
  use RemitWeb, :live_view

  alias Remit.{Repo,Commit}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, %{
      commits: get_commits(),
      unreviewed_count: unreviewed_count(),
    })

    # https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-dom-patching-and-temporary-assigns
    {:ok, socket, temporary_assigns: [commits: []]}
  end

  @impl true
  def handle_event("mark_reviewed", %{"commit_id" => cid}, socket) do
    # TODO: Allow useconds in DB so we don't need this dance
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    commit = Repo.get_by(Commit, id: cid) |> Ecto.Changeset.change(%{reviewed_at: now}) |> Repo.update!() |> Repo.preload(:author)

    # Can send the single commit thanks to https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-dom-patching-and-temporary-assigns
    {:noreply, assign(socket, %{ commits: [commit], unreviewed_count: unreviewed_count() })}
  end

  @impl true
  def handle_event("mark_unreviewed", %{"commit_id" => cid}, socket) do
    commit = Repo.get_by(Commit, id: cid) |> Ecto.Changeset.change(%{reviewed_at: nil}) |> Repo.update!() |> Repo.preload(:author)

    # Can send the single commit thanks to https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-dom-patching-and-temporary-assigns
    {:noreply, assign(socket, %{ commits: [commit], unreviewed_count: unreviewed_count() })}
  end

  defp unreviewed_count do
    (from c in Commit, where: is_nil(c.reviewed_at))
    |> Repo.aggregate(:count)
  end

  defp get_commits do
    query = from c in Commit,
        limit: 200,
        order_by: [desc: c.inserted_at],
        preload: :author

    Repo.all(query)
  end
end
