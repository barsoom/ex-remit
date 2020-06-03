defmodule RemitWeb.ConnectionChannel do
  use RemitWeb, :channel

  def join(_channel, _auth, socket) do
    {:ok, socket}
  end
end
