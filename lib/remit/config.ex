defmodule Remit.Config do
  @moduledoc false

  def auth_key, do: Confex.fetch_env!(:remit, :auth_key)

  def webhook_key, do: Confex.fetch_env!(:remit, :webhook_key)

  def github_api_token, do: Confex.fetch_env!(:remit, :github_api_token)

  def github_oauth_client_id, do: Confex.fetch_env!(:remit, :github_oauth_client_id)

  def github_oauth_client_secret, do: Confex.fetch_env!(:remit, :github_oauth_client_secret)

  def github_org_slug, do: Confex.fetch_env!(:remit, :github_org_slug)

  def has_github_org?, do: github_org_slug() != ""
end
