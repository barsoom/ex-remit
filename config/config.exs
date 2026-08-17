# This file is responsible for configuring your application
# and its dependencies.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :remit,
  ecto_repos: [Remit.Repo],
  favicon: "favicon.png",
  # If too low, we may miss stuff. If too high, performance may suffer.
  max_commits: 300,
  max_comments: 150,
  # Defaults for the per-user "hide reviewed commits after" setting.
  reviewed_commit_cutoff_days: 90,
  reviewed_commit_cutoff_commits: 300,
  github_org_slug: {:system, "GITHUB_ORG_SLUG", ""},
  github_api_client: Remit.GitHubAPIClient,
  ignored_repo_prefixes: {:system, "IGNORED_REPO_PREFIXES", ""}

# Configures the endpoint
config :remit, RemitWeb.Endpoint,
  url: [host: "localhost"],
  # Overridden in prod.secret.exs.
  secret_key_base: "VwHFDH5VSFj8+cVvqb/2V15wtR9RMmkpIVnID1PrHMWTT7LNxSn/Nl0RGDavQGER",
  render_errors: [
    formats: [html: RemitWeb.ErrorHTML, json: RemitWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Remit.PubSub,
  live_view: [signing_salt: "s9WcFK/G"]

config :remit, App.Repo, migration_timestamps: [type: :utc_datetime_usec]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :elixir, :time_zone_database, Tz.TimeZoneDatabase
config :tesla, adapter: {Tesla.Adapter.Finch, name: Remit.Finch}

config :sentry,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  in_app_otp_apps: [:remit],
  enable_logs: true,
  logs: [level: :warning, metadata: :all, capture_metadata: :all],
  traces_sampler: &Remit.SentrySampler.sample/1

config :opentelemetry,
  span_processor: {Sentry.OpenTelemetry.SpanProcessor, []},
  sampler: {Sentry.OpenTelemetry.Sampler, []},
  text_map_propagators: [
    :trace_context,
    :baggage,
    Sentry.OpenTelemetry.Propagator
  ]

config :esbuild,
  version: "0.17.12",
  default: [
    args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# We run the npm-installed Tailwind CLI rather than the standalone binary: the
# standalone bundles its own old Node, which our PostCSS plugins have outgrown.
# The version lives in assets/package.json.
config :tailwind,
  version_check: false,
  path: Path.expand("../assets/node_modules/.bin/tailwindcss", __DIR__),
  default: [
    args: ~w(
      --config=tailwind.config.js
      --postcss=postcss.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
