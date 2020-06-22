defmodule RemitWeb.NoUsernameComponent do
  use RemitWeb, :live_component

  def render(assigns) do
    tooltip? = Map.get(assigns, :tooltip?, true)

    ~L"""
      <span
        class="bg-gray-light rounded py-px px-1 text-gray-dark"
        <%= if tooltip?, do: render_tooltip(~s(Read about usernames under the "Settings" tab.), pos: "up-left") %>
      ><i class="fas fa-exclamation-circle text-red-600"></i> no username</span>
    """
  end
end
