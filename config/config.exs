# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :remit,
  ecto_repos: [Remit.Repo],
  favicon: "favicon.png",
  # If too low, we may miss stuff. If too high, performance may suffer.
  max_commits: 300,
  max_comments: 300

# Configures the endpoint
config :remit, RemitWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "VwHFDH5VSFj8+cVvqb/2V15wtR9RMmkpIVnID1PrHMWTT7LNxSn/Nl0RGDavQGER",  # Overridden in prod.secret.exs.
  render_errors: [view: RemitWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Remit.PubSub,
  live_view: [signing_salt: "s9WcFK/G"]

config :remit, App.Repo,
  migration_timestamps: [type: :utc_datetime_usec],
  github_api_client: Remit.GitHubAPIClient

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
config :tesla, adapter: Tesla.Adapter.Hackney

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
