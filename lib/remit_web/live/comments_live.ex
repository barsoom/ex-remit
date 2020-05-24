defmodule RemitWeb.CommentsLive do
  use RemitWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    check_auth_key(params, session)

    {:ok, socket}
  end
end
