defmodule Remit.Settings do
  @moduledoc """
  User settings.
  """
  alias Phoenix.PubSub

  @spec subscribe(binary) :: :ok | {:error, {:already_registered, pid}}
  def subscribe(session_id), do: PubSub.subscribe(Remit.PubSub, session_topic(session_id))

  @spec broadcast(binary, atom(), any) :: :ok | {:error, any}
  def broadcast(session_id, key, value),
    do: PubSub.broadcast(Remit.PubSub, session_topic(session_id), {:setting_updated, key, value})

  @spec session_topic(binary) :: binary
  defp session_topic(session_id), do: "settings:" <> session_id
end
