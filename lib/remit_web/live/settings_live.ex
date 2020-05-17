defmodule RemitWeb.SettingsLive do
  use RemitWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, %{
      page_title: "Settings",
      email: "",
      name: "",
    })

    {:ok, socket}
  end

  @impl true
  def handle_event("form_change", %{"email" => email, "name" => name}, socket) do
    {:noreply, assign(socket, email: email, name: name)}
  end

  @impl true
  def handle_event("restore", %{"email" => email, "name" => name}, socket) do
    {:noreply, assign(socket, email: email, name: name)}
  end
end
