defmodule RemitWeb.PageLive do
  use RemitWeb, :live_view

  alias Remit.{Repo,Commit}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    commits = get_commits()
    {:ok, assign(socket, get_data())}
  end

  @impl true
  def handle_event("mark_reviewed", %{"commit_id" => cid}, socket) do

    # TODO: Allow useconds in DB so we don't need this dance
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Repo.get_by(Commit, id: cid)
      |> Ecto.Changeset.change(%{reviewed_at: now})
      |> Repo.update!()

    # TODO: We could probably change `commits` in place instead of re-querying.
    {:noreply, assign(socket, get_data())}
  end

  @impl true
  def handle_event("mark_unreviewed", %{"commit_id" => cid}, socket) do
    Repo.get_by(Commit, id: cid)
      |> Ecto.Changeset.change(%{reviewed_at: nil})
      |> Repo.update!()

    # TODO: We could probably change `commits` in place instead of re-querying.
    {:noreply, assign(socket, get_data())}
  end

  defp get_data do
    unreviewed_count = (from c in Commit, where: is_nil(c.reviewed_at))
      |> Repo.aggregate(:count)

    %{
      commits: get_commits(),
      unreviewed_count: unreviewed_count,
    }
  end

  defp get_commits do
    query = from c in Commit,
        limit: 200,
        order_by: [desc: c.inserted_at],
        preload: :author

    Repo.all(query)
  end
end
