defmodule Remit.Config do
  @moduledoc false

  def auth_key, do: Confex.fetch_env!(:remit, :auth_key)

  def webhook_key, do: Confex.fetch_env!(:remit, :webhook_key)

  def github_api_token, do: Confex.fetch_env!(:remit, :github_api_token)
end
