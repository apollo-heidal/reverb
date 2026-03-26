import Config

config :reverb,
  mode: :disabled

config :reverb, Reverb.Agent,
  enabled: false

config :reverb, Reverb.Repo,
  database: "reverb_test#{System.get_env("MIX_TEST_PARTITION")}",
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :logger, level: :warning
