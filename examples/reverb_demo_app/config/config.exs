import Config

config :reverb_demo_app,
  emit_interval_ms: String.to_integer(System.get_env("DEMO_EMIT_INTERVAL_MS") || "30000"),
  repeat_backlog: System.get_env("DEMO_REPEAT_BACKLOG") == "true"

config :reverb,
  mode: :emitter,
  topic_hash: System.get_env("REVERB_TOPIC_HASH") || "reverb-demo-app",
  pubsub_name: ReverbDemoApp.PubSub

config :reverb, Reverb.Emitter,
  logger_handler: false,
  telemetry_events: []
