defmodule RemitWeb.Layouts do
  @moduledoc false
  use RemitWeb, :html

  embed_templates "layouts/*"

  defp tab(assigns) do
    ~H"""
    <.link patch={@url} class={tab_class(assigns)} title={@show_notification_bell && "You have unresolved comments ;)"}>
      <span class="relative inline-block">
        <i class={["fas", @icon]}></i>
        <%= if @notification_count && @notification_count > 0 do %>
          <span class="inline-flex items-center justify-center absolute top-0 -right-2.5 min-w-[0.75rem] h-3 px-1 text-[8px] font-light leading-none text-red-100 dark:text-blue-100 bg-red-600 dark:bg-blue-600 rounded-full">
            <%= @notification_count %>
          </span>
        <% else %>
          <%= if @show_notification_bell do %>
            <span class="inline-block absolute -top-0.5 -right-0.5 w-2 h-2 bg-red-600 border rounded-full"></span>
          <% end %>
        <% end %>
      </span>
      <span class="tabs__tab__text"><%= @text %></span>
    </.link>
    """
  end

  defp tab_class(%{action: action, current_action: action} = opts) do
    base_classes(opts) ++ ["tabs__tab--current"]
  end

  defp tab_class(%{action: _action} = opts), do: base_classes(opts)

  defp base_classes(%{action: action}) do
    ["tabs__tab", "tabs__tab--#{action}", "relative"]
  end
end
