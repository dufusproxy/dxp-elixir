import Config

config :core, Core.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "core_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
