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
      <%# Using the params in the ID means it will be re-mounted if params change. %>
      <%= live_render @socket, RemitWeb.CommentsLive, id: "comments_#{@is}_#{@role}", session: %{"is" => @is, "role" => @role} %>
    </div>

    <div style="display: <%= if @live_action == :settings, do: "block", else: "none" %>">
      <%= live_render @socket, RemitWeb.SettingsLive, id: :settings %>
    </div>
    """
  end

  @impl true
  def mount(params, session, socket) do
    check_auth_key(session)
    {:ok, assign_from_comment_params(socket, params)}
  end

  # Needs to be defined for re-rendering to happen.
  @impl true
  def handle_params(params, _uri, socket) do
    # Since the child LiveViews run concurrently, they can't be relied on to set the title.
    socket =
      case socket.assigns.live_action do
        :commits ->
          assign(socket, :page_title, "Commits")

        :comments ->
          socket
          |> assign(page_title: "Comments")
          |> assign_from_comment_params(params)

        :settings ->
          assign(socket, :page_title, "Settings")
      end

    {:noreply, socket}
  end

  defp assign_from_comment_params(socket, params) do
    assign(socket, is: params["is"], role: params["role"])
  end
end
