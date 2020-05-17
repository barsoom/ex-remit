defmodule RemitWeb.SettingsLive do
  use RemitWeb, :live_view
  alias Remit.{Repo,Settings}

  @impl true
  def mount(_params, session, socket) do
    settings = Settings.for_session(session)

    socket = assign(socket, %{
      page_title: "Settings",
      settings: settings,
    })

    {:ok, socket}
  end

  @impl true
  def handle_event("form_change", %{"email" => email, "name" => name}, socket) do
    settings = socket.assigns.settings
    changeset = settings |> Ecto.Changeset.change(email: email, name: name)
    settings = if settings.id, do: Repo.update!(changeset), else: Repo.insert!(changeset)

    {:noreply, assign(socket, settings: settings)}
  end
end
