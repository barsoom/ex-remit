# Provides a tabbed interface that avoids re-mounting LiveViews.
# Read more: https://elixirforum.com/t/tabbed-interface-with-multiple-liveviews/31670
defmodule RemitWeb.TabsLive do
  use RemitWeb, :live_view

  @impl true
  def render(assigns) do
    ~L"""
    <div style="display: <%= if @live_action == :commits, do: "block", else: "none" %>">
      <%= live_render @socket, RemitWeb.CommitsLive, id: :commits %>
    </div>

    <div style="display: <%= if @live_action == :comments, do: "block", else: "none" %>">
      <%= live_render @socket, RemitWeb.CommentsLive, id: :comments %>
    </div>

    <div style="display: <%= if @live_action == :settings, do: "block", else: "none" %>">
      <%= live_render @socket, RemitWeb.SettingsLive, id: :settings %>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  # Needs to be defined for re-rendering to happen.
  @impl true
  def handle_params(_params, _uri, socket) do
    # Since the child LiveViews run concurrently, they can't be relied on to set the title.
    socket =
      case socket.assigns.live_action do
        :commits ->
          assign(socket, :page_title, "Commits")
        :comments ->
          assign(socket, :page_title, "Comments")
        :settings ->
          assign(socket, :page_title, "Settings")
      end

    {:noreply, socket}
  end
end
