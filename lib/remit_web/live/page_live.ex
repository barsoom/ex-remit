defmodule RemitWeb.PageLive do
  use RemitWeb, :live_view
  alias Remit.{Repo,Commit}

  @impl true
  def mount(_params, _session, socket) do
    commits = get_commits()
    {:ok, assign(socket, query: "", commits: commits, results: %{})}
  end

  @impl true
  def handle_event("mark_reviewed", %{"commit_id" => cid}, socket) do

    # TODO: Allow useconds in DB so we don't need this dance
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Repo.get_by(Commit, id: cid)
      |> Ecto.Changeset.change(%{reviewed_at: now})
      |> Repo.update!()

    # TODO: We could probably change `commits` in place instead of re-querying.
    commits = get_commits()

    {:noreply, socket |> assign(results: %{}, commits: commits, query: "")}
  end

  @impl true
  def handle_event("mark_unreviewed", %{"commit_id" => cid}, socket) do

    Repo.get_by(Commit, id: cid)
      |> Ecto.Changeset.change(%{reviewed_at: nil})
      |> Repo.update!()

    # TODO: We could probably change `commits` in place instead of re-querying.
    commits = get_commits()

    {:noreply, socket |> assign(results: %{}, commits: commits, query: "")}
  end

  defp get_commits do
    import Ecto.Query

    query = from c in Commit,
        limit: 200,
        order_by: [desc: c.inserted_at],
        preload: :author

    Repo.all(query)
  end
end
