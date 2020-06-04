defmodule RemitWeb.ConnectionDetectionSocket do
  use Phoenix.Socket

  @impl true
  def connect(socket_params, socket, _connect_info) do
    if RemitWeb.Auth.Socket.authed_via_socket_params?(socket_params) do
      {:ok, socket}
    else
      :error
    end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     RemitWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(_socket), do: nil
end
