import Config

config :core,
  ash_domains: [Core.Domain],
  ecto_repos: [Core.Repo]

config :core, Core.Repo,
  username: System.get_env("PG_USER") || "postgres",
  password: System.get_env("PG_PASSWORD") || "postgres",
  hostname: System.get_env("PG_HOST") || "localhost",
  database: System.get_env("PG_DATABASE") || "core_dev",
  port: System.get_env("PG_PORT", "5432") |> String.to_integer(),
  pool_size: 10,
  show_sensitive_data_on_connection_error: true

import_config "#{config_env()}.exs"
