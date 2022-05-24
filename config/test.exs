import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
if System.get_env("DEVBOX") do
  {postgres_port, 0} = System.cmd("service_port", ["postgres"])

  config :remit, Remit.Repo,
    username: "postgres",
    password: "dev",
    database: "ex_remit_test",
    hostname: "172.17.0.1",
    port: String.trim(postgres_port),
    pool: Ecto.Adapters.SQL.Sandbox
else
  config :remit, Remit.Repo,
    database: "remit_test#{System.get_env("MIX_TEST_PARTITION")}",
    hostname: "localhost",
    username: System.get_env("POSTGRES_USER") || System.get_env("USER"),
    password: System.get_env("POSTGRES_PASSWORD") || "",
    pool: Ecto.Adapters.SQL.Sandbox
end

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :remit, RemitWeb.Endpoint,
  http: [port: 4002],
  server: false

config :remit,
  auth_key: "test_auth_key",
  webhook_key: "test_webhook_key",
  github_api_token: "test_github_api_token",
  github_api_client: GitHubAPIClient.Mock

config :tesla, adapter: Tesla.Mock

# Print only warnings and errors during test
config :logger, level: :warn

config :honeybadger,
  environment_name: :test,
  api_key: "not-used"
