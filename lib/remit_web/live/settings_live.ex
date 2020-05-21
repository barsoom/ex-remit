defmodule RemitWeb.SettingsLive do
  use RemitWeb, :live_view
  alias Remit.{Repo,Settings}

  @impl true
  def mount(_params, session, socket) do
    settings = Settings.for_session(session)

    socket = assign(socket, %{
      settings: settings,
    })

    {:ok, socket}
  end

  @impl true
  def handle_event("form_change", %{"email" => _, "name" => _} = fields, socket) do
    settings = socket.assigns.settings
    changeset = settings |> Settings.form_changeset(fields)
    settings = if settings.id, do: Repo.update!(changeset), else: Repo.insert!(changeset)

    Settings.broadcast_changed_settings(settings)

    {:noreply, assign(socket, settings: settings)}
  end
end
