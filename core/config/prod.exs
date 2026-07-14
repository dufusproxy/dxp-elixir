import Config

# Production configuration

config :core, Core.Repo, pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

# Configure Phoenix endpoint for production
config :core, CoreWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST") || "example.com", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: System.get_env("SECRET_KEY_BASE")
