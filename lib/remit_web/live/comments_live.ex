defmodule RemitWeb.CommentsLive do
  use RemitWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    check_auth_key(session)

    {:ok, socket}
  end
end
