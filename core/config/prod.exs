import Config

# Production configuration

config :core, Core.Repo, pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
