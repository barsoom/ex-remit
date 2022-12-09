defmodule RemitWeb.LayoutView do
  use RemitWeb, :view
  alias RemitWeb.Endpoint

  defp tab(assigns) do
    ~H"""
    <%= link(to: Routes.tabs_path(Endpoint, @action), class: tab_class(assigns)) do %>
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
