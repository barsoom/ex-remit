defmodule RemitWeb.SettingsLive do
  use RemitWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, %{
      page_title: "Settings",
      name: "",
    })

    {:ok, socket}
  end

  @impl true
  def handle_event("name_change", %{"name" => name}, socket) do
    {:noreply, assign(socket, :name, name)}
  end
end
