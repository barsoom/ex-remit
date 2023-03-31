defmodule RemitWeb.NoUsernameComponent do
  @moduledoc false
  use RemitWeb, :live_component

  def render(assigns) do
    ~H"""
    <span
      class="bg-gray-light rounded py-px px-1 text-gray-dark"
    >
      <i class="fas fa-exclamation-circle text-red-600"></i> no username
    </span>
    """
  end
end
