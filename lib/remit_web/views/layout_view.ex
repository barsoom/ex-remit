defmodule RemitWeb.LayoutView do
  use RemitWeb, :view
  alias RemitWeb.Endpoint
  require Logger

  defp tab(assigns) do
    Logger.info(tab_assigns: assigns)
    ~H"""
    <%= live_patch(to: Routes.tabs_path(Endpoint, @action), class: tab_class(assigns)) do %>
      <i class={["fas", @icon]}></i>
      <span class="tabs__tab__text"><%= @text %></span>
    <% end %>
    """
  end

  defp tab_class(%{action: action, current_action: action}) do
    ["tabs__tab", "tabs__tab--#{action}", "tabs__tab--current"]
  end
  defp tab_class(%{action: action}) do
    ["tabs__tab", "tabs__tab--#{action}"]
  end
end
