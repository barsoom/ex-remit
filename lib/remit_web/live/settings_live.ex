defmodule RemitWeb.SettingsLive do
  use RemitWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    check_auth_key(session)

    socket =
      assign(socket,
        email: session["email"],
        username: session["username"]
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("form_change", %{"email" => email, "username" => username}, socket) do
    socket =
      assign(socket,
        email: Remit.Utils.normalize_string(email),
        username: Remit.Utils.normalize_string(username)
      )

    {:noreply, socket}
  end
end
