import Config

if System.get_env("PHX_SERVER") in ["true", "1"] do
  config :remit, LoganWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :remit, Remit.Repo,
    ssl: true,
    ssl_opts: [verify: :verify_none],
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :remit, RemitWeb.Endpoint,
    http: [
      port: String.to_integer(System.get_env("PORT") || "4000"),
      transport_options: [socket_opts: [:inet6]],
      protocol_options: [
        idle_timeout: 15_000
      ]
    ],
    secret_key_base: secret_key_base,
    url: [scheme: "https", host: System.get_env("HOST"), port: 443],
    force_ssl: [rewrite_on: [:x_forwarded_proto]],
    cache_static_manifest: "priv/static/cache_manifest.json"

  config :remit,
    auth_key: System.get_env("AUTH_KEY"),
    webhook_key: System.get_env("WEBHOOK_KEY"),
    github_api_token: System.get_env("GITHUB_API_TOKEN"),
    github_oauth_client_id: System.get_env("GITHUB_OAUTH_CLIENT_ID"),
    github_oauth_client_secret: System.get_env("GITHUB_OAUTH_CLIENT_SECRET")
end
