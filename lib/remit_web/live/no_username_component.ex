defmodule RemitWeb.NoUsernameComponent do
  @moduledoc false
  use RemitWeb, :live_component

  def render(assigns) do
    ~H"""
    <%!-- One line to avoid stray whitespace inside the badge; phx-no-format keeps `mix format` from re-expanding it. --%>
    <span phx-no-format class="bg-gray-light rounded py-px px-1 text-gray-dark"><i class="fas fa-exclamation-circle text-red-600"></i> no username</span>
    """
  end
end
