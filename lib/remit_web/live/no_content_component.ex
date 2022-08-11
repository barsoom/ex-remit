defmodule RemitWeb.NoContentComponent do
  @moduledoc false
  use RemitWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="mt-10 text-center">
      <p><i class="fad fa-star-shooting text-6xl text-yellow-500"></i></p>
      <p class="text-lg text-gray-mid pt-3">Nothing yet!</p>
    </div>
    """
  end
end
