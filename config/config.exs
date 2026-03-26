import Config

config :reverb,
  mode: :disabled,
  topic_hash: "default",
  pubsub_name: nil

config :reverb, Reverb.Emitter,
  logger_handler: false,
  telemetry_events: [],
  levels: [:error, :warning]

config :reverb, Reverb.Receiver,
  prod_node: nil,
  reconnect_interval_ms: 10_000,
  allowed_nodes: []

config :reverb, Reverb.Agent,
  enabled: false,
  boot_delay_ms: 30_000,
  cooldown_ms: 30_000,
  idle_rotation_ms: 900_000,
  task_timeout_ms: 600_000,
  max_consecutive_failures: 3,
  backoff_base_ms: 120_000,
  backoff_max_ms: 900_000,
  agent_command: "claude",
  agent_args: ["--dangerously-skip-permissions", "--print"],
  project_root: nil,
  rotation_tasks: :default

config :reverb, Reverb.Repo,
  database: "reverb_dev",
  username: "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  hostname: System.get_env("PHX_POSTGRES_HOST") || "localhost",
  pool_size: 5

config :reverb, ecto_repos: [Reverb.Repo]

import_config "#{config_env()}.exs"
