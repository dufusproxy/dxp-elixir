import Config

config :core,
  ash_domains: [Core.Domain],
  ecto_repos: [Core.Repo]

config :core, Core.Repo,
  username: System.get_env("PG_USER") || "postgres",
  password: System.get_env("PG_PASSWORD") || "postgres",
  hostname: System.get_env("PG_HOST") || "localhost",
  database: System.get_env("PG_DATABASE") || "core_dev",
  port: System.get_env("PG_PORT") || "5432",
  pool_size: 10

import_config "#{config_env()}.exs"
