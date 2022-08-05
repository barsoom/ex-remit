# Provides a tabbed interface that avoids re-mounting LiveViews.
# Read more: https://elixirforum.com/t/tabbed-interface-with-multiple-liveviews/31670
defmodule RemitWeb.TabsLive do
  use RemitWeb, :live_view

  @tabs [
    %{action: :commits, module: RemitWeb.CommitsLive, text: "Commits", icon: "fa-eye"},
    %{action: :comments, module: RemitWeb.CommentsLive, text: "Comments", icon: "fa-comments"},
    %{action: :settings, module: RemitWeb.SettingsLive, text: "Settings", icon: "fa-cog"},
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <%= for tab <- @tabs do %>
      <div style={"display: #{if @live_action == tab.action, do: "block", else: "none"}"}>
        <%= live_render @socket, tab.module, id: tab.action %>
      </div>
    <% end %>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    check_auth_key(session)
    socket = assign(socket, tabs: @tabs)
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    # Since the child LiveViews run concurrently, they can't be relied on to set the title themselves.
    socket = assign_page_title(socket)

    {:noreply, socket}
  end

  defp assign_page_title(%{assigns: %{live_action: action}} = socket) do
    assign(socket, page_title: page_title(action))
  end

  # Maybe reuse the @tabs definitions if we want the page title to match the tab text
  defp page_title(:commits), do: "Commits"
  defp page_title(:comments), do: "Comments"
  defp page_title(:settings), do: "Settings"
end
