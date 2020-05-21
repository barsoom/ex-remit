defmodule RemitWeb.CommentsLive do
  use RemitWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
