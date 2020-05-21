defmodule RemitWeb.LayoutView do
  use RemitWeb, :view

  defp tab(action, text, icon, socket, live_action) do
    live_patch(to: Routes.tabs_path(socket, action), class: "tabs__tab #{if live_action == action, do: "tabs__tab--#{action} tabs__tab--current"}") do
      ~E"""
      <i class="fas <%= icon %> mr-1"></i>
      <%= text %>
      """
    end
  end
end
