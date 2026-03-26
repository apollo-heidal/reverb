import Config

if config_env() == :prod do
  config :reverb, Reverb.Repo,
    url: System.get_env("REVERB_DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("REVERB_POOL_SIZE") || "5")
end
