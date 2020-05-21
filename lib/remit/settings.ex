defmodule Remit.Settings do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Remit.{Repo,Settings}

  @stale_after_days 100

  schema "settings" do
    field :email, :string
    field :name, :string
    field :read_at, :utc_datetime_usec
    field :session_id, Ecto.UUID

    timestamps()
  end

  @doc false
  def form_changeset(settings, attrs) do
    settings
    |> cast(attrs, [:name, :email])
    |> update_change(:name, &normalize_string/1)
    |> update_change(:email, &normalize_string/1)
  end

  def authored?(%Settings{name: nil}, _commit), do: false
  def authored?(settings, commit) do
    String.contains?(commit.author_name, settings.name)
  end

  def for_session(%{"session_id" => sid}) do
    settings = Repo.get_by(Settings, session_id: sid)

    if settings do
      # Update `read_at` so we can track stale Settings.
      settings = settings |> Ecto.Changeset.change(read_at: DateTime.utc_now()) |> Repo.update!

      # Delete stale Settings so DB doesn't keep them forever. It's cheap enough to do on every call.
      Repo.delete_all(from s in Settings, where: s.read_at < ago(@stale_after_days, "day"))

      settings
    else
      %Settings{session_id: sid}
    end
  end

  def subscribe_to_changed_settings(settings) do
    Phoenix.PubSub.subscribe(Remit.PubSub, broadcast_topic(settings))
  end

  def broadcast_changed_settings(settings) do
    Phoenix.PubSub.broadcast_from(Remit.PubSub, self(), broadcast_topic(settings), {:changed_settings, settings})
  end

  # Private

  defp broadcast_topic(settings), do: "settings:#{settings.session_id}"

  defp normalize_string(nil), do: nil
  defp normalize_string(string) do
    string = String.trim(string)
    if string == "", do: nil, else: string
  end
end
