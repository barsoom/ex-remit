# Provides a tabbed interface that avoids re-mounting LiveViews.
# Read more: https://elixirforum.com/t/tabbed-interface-with-multiple-liveviews/31670
defmodule RemitWeb.TabsLive do
  use RemitWeb, :live_view

  @impl true
  def render(assigns) do
    ~L"""
    <div id="target-tabs"></div>

    <div style="display: <%= if @live_action == :commits, do: "block", else: "none" %>">
      <%#= live_render @socket, RemitWeb.CommitsLive, id: :commits %>
    </div>

    <div style="display: <%= if @live_action == :comments, do: "block", else: "none" %>">
      <%# Using the params in the ID means it will be re-mounted if params change. %>
      <%= live_component @socket, RemitWeb.CommentsComponent, id: :comments, username: @username, params: comments_params(@params) %>
    </div>

    <div style="display: <%= if @live_action == :settings, do: "block", else: "none" %>">
      <%= live_component @socket, RemitWeb.SettingsComponent, id: :settings, username: @username %>
    </div>
    """
  end

  @impl true
  def mount(params, session, socket) do
    check_auth_key(session)

    socket = assign(socket,
      username: session["username"],
      params: params
    )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Since the child LiveViews run concurrently, they can't be relied on to set the title.
    socket =
      case socket.assigns.live_action do
        :commits ->
          assign(socket, page_title: "Commits")

        :comments ->
          assign(socket, page_title: "Comments", params: params)

        :settings ->
          assign(socket, page_title: "Settings")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("settings_form_change", %{"username" => username}, socket) do
    IO.inspect {:tabs_form_change, username: username}
    {:noreply, assign(socket, username: Remit.Utils.normalize_string(username))}
  end

  defp comments_params(params), do: Map.take(params, ["resolved", "user"])
end
