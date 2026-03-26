import Config

config :reverb,
  mode: :receiver

config :reverb, Reverb.Agent,
  enabled: true

config :reverb, Reverb.Repo,
  database: "reverb_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true
