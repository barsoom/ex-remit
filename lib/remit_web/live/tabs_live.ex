# Provides a tabbed interface that avoids re-mounting LiveViews.
# Read more: https://elixirforum.com/t/tabbed-interface-with-multiple-liveviews/31670
defmodule RemitWeb.TabsLive do
  use RemitWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div style={"display: #{if @live_action == :commits, do: "block", else: "none"}"}>
      <%= live_render @socket, RemitWeb.CommitsLive, id: :commits %>
    </div>

    <div style={"display: #{if @live_action == :comments, do: "block", else: "none"}"}>
      <%= live_render @socket, RemitWeb.CommentsLive, id: :comments, session: %{"is" => @comments_is, "role" => @comments_role} %>
    </div>

    <div style={"display: #{if @live_action == :settings, do: "block", else: "none"}"}>
      <%= live_render @socket, RemitWeb.SettingsLive, id: :settings %>
    </div>
    """
  end

  @impl true
  def mount(params, session, socket) do
    check_auth_key(session)
    {:ok, assign_from_comment_params(socket, params)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Since the child LiveViews run concurrently, they can't be relied on to set the title themselves.
    socket =
      case socket.assigns.live_action do
        :commits ->
          assign(socket, page_title: "Commits")

        :comments ->
          socket
          |> assign(page_title: "Comments")
          |> assign_from_comment_params(params)
          |> forward_comment_params(params)

        :settings ->
          assign(socket, page_title: "Settings")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:comments_pid, pid}, socket) do
    {:noreply, assign(socket, comments_pid: pid)}
  end

  defp forward_comment_params(%{assigns: %{comments_pid: comments_pid}} = socket, params) do
    send comments_pid, {:new_params, params}
    socket
  end

  # We don't have the PID yet on mount, but that's OK.
  # If there are any params on mount, we'll pass them to CommentsLive as part of the `session` parameter.
  defp forward_comment_params(socket, _params), do: socket

  defp assign_from_comment_params(socket, params) do
    assign(socket, comments_is: params["is"], comments_role: params["role"])
  end
end
