defmodule Remit.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :remit,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Remit.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, ">= 1.5.13"},
      {:phoenix_ecto, "> 0.0.0"},
      {:ecto_sql, "> 0.0.0"},
      {:postgrex, "> 0.0.0"},
      {:phoenix_live_view, ">= 0.16.4"},
      {:floki, "> 0.0.0", only: :test},
      {:phoenix_html, "> 0.0.0"},
      {:phoenix_live_reload, "> 0.0.0", only: :dev},
      {:phoenix_live_dashboard, "> 0.0.0"},
      {:telemetry_metrics, "> 0.0.0"},
      {:telemetry_poller, "> 0.0.0"},
      {:gettext, "> 0.0.0"},
      {:jason, "> 0.0.0"},
      {:plug_cowboy, "> 0.0.0"},
      {:tzdata, "> 0.0.0"},
      {:honeybadger, "> 0.0.0"},
      {:tesla, "> 0.0.0"},
      {:hackney, "> 0.0.0"},
      {:confex, "~> 3.5.0"},
      {:mox, "> 0.0.0", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:git_hooks, "~> 0.7.0", only: [:dev], runtime: false},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd npm install --prefix assets"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
      "wh.commits": ["run priv/repo/fake_webhook_commits.exs"],
      "wh.comments": ["run priv/repo/fake_webhook_comments.exs"]
    ]
  end
end

# See the documentation for `Mix` for more info on aliases.
