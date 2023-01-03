defmodule RemitWeb.LayoutView do
  use RemitWeb, :view
  alias RemitWeb.Endpoint

  defp tab(assigns) do
    ~H"""
    <.link patch={Routes.tabs_path(Endpoint, @action)} class={tab_class(assigns)}>
      <i class={["fas", @icon]}></i>
      <span class="tabs__tab__text"><%= @text %></span>
      <%= if @show_notification_bell do %>
        <span class="inline-block absolute top-2 right-2 w-2 h-2 bg-red-600 border rounded-full"></span>
      <% end %>
    </.link>
    """
  end

  defp tab_class(%{action: action, current_action: action}) do
    ["tabs__tab", "tabs__tab--#{action}", "relative", "tabs__tab--current"]
  end

  defp tab_class(%{action: action}) do
    ["tabs__tab", "tabs__tab--#{action}", "relative"]
  end
end
