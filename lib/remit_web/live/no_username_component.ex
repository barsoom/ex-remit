defmodule RemitWeb.NoUsernameComponent do
  use RemitWeb, :live_component

  def render(assigns) do
    tooltip? = Map.get(assigns, :tooltip?, true)

    ~H"""
      <span
        class="bg-gray-light rounded py-px px-1 text-gray-dark"
        {if tooltip?, do: tooltip_attributes(~s(Read about usernames under the "Settings" tab.), pos: "up-left"), else: []}
      ><i class="fas fa-exclamation-circle text-red-600"></i> no username</span>
    """
  end
end
