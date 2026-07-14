import Config

# In development, we use a simpler logging level
config :core, Core.Repo, log: :debug

# Configure Phoenix endpoint
config :core, CoreWeb.Endpoint,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 4000],
  secret_key_base: "K7H1sBQ2xM3yN4oP5zR6sT8uV9wX0yZ1aB2cD3eF4gH5iJ6kL7mN8oP9qR0sT1u",
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  watch_static: true

# Enable LiveDashboard in development
config :phoenix, :stacktrace_depth, 20

