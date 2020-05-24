defmodule RemitWeb.SettingsLive do
  use RemitWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    check_auth_key(params, session)

    socket = assign(socket,
      email: session["email"],
      name: session["name"]
    )

    {:ok, socket}
  end

  @impl true
  def handle_event("form_change", %{"email" => email, "name" => name}, socket) do
    socket = assign(socket,
      email: Remit.Utils.normalize_string(email),
      name: Remit.Utils.normalize_string(name)
    )

    {:noreply, socket}
  end
end
