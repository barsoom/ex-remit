defmodule RemitWeb.LayoutView do
  use RemitWeb, :view

  defp tab(action, text, icon, socket, live_action, params \\ []) do
    params = if Keyword.values(params) |> Enum.all?(&(!&1)), do: [], else: params

    live_patch(to: Routes.tabs_path(socket, action, params), class: "tabs__tab tabs__tab--#{action} #{if live_action == action, do: "tabs__tab--current"}") do
      ~E"""
      <i class="fas <%= icon %>"></i>
      <span class="tabs__tab__text"><%= text %></span>
      """
    end
  end
end
