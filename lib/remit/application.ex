defmodule Remit.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Remit.Repo,
      # Start the Telemetry supervisor
      RemitWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, [name: Remit.PubSub]},
      Remit.Ownership,
      Remit.GithubAuth,
      Remit.Periodically,
      # Start the Endpoint (http/https)
      RemitWeb.Endpoint
      # Start a worker by calling: Remit.Worker.start_link(arg)
      # {Remit.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Remit.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    RemitWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
