import Config

# Configure your database
config :core, Core.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "core_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Configure Phoenix endpoint for testing
config :core, CoreWeb.Endpoint,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 4001],
  secret_key_base: "test_secret_key_base_for_testing_only",
  server: false

# We don't run a server during test.
config :logger, level: :warning
