defmodule RemitWeb.LayoutView do
  use RemitWeb, :view

  defp tab(assigns, action, text, icon, socket, live_action) do
    live_patch(to: Routes.tabs_path(socket, action), class: "tabs__tab tabs__tab--#{action} #{if live_action == action, do: "tabs__tab--current"}") do
      ~H"""
      <i class={["fas", icon]}></i>
      <span class="tabs__tab__text"><%= text %></span>
      """
    end
  end
end
