defmodule RemitWeb.CommentsLive do
  use RemitWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(100, self(), :tick)

    socket = assign(socket, %{
      page_title: "Comments",
      time: now(),
    })

    {:ok, socket}
  end

  def handle_info(:tick, socket) do
    {:noreply, assign(socket, :time, now())}
  end

  defp now, do: DateTime.utc_now()
end
