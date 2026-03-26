import Config

if config_env() == :prod do
  config :reverb, Reverb.Repo,
    url: System.get_env("REVERB_DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("REVERB_POOL_SIZE") || "5")

  # Mode override (emitter, receiver, disabled)
  if mode = System.get_env("REVERB_MODE") do
    config :reverb, mode: String.to_atom(mode)
  end

  # Standalone receiver: start PubSub in this VM (not needed when embedded in a host app)
  if System.get_env("REVERB_START_PUBSUB") == "true" do
    config :reverb, start_pubsub: true
  end

  # PubSub name override (must match the host app's PubSub for cross-node :pg messaging)
  if pubsub = System.get_env("REVERB_PUBSUB_NAME") do
    config :reverb, pubsub_name: String.to_atom("Elixir.#{pubsub}")
  end

  # Topic hash override (both emitter and receiver must agree on this)
  if topic = System.get_env("REVERB_TOPIC_HASH") do
    config :reverb, topic_hash: topic
  end

  # Receiver: which prod node to connect to and which nodes to allow
  if prod_node = System.get_env("REVERB_PROD_NODE") do
    allowed =
      (System.get_env("REVERB_ALLOWED_NODES") || "")
      |> String.split(",", trim: true)
      |> Enum.map(&String.to_atom(String.trim(&1)))

    config :reverb, Reverb.Receiver,
      prod_node: String.to_atom(prod_node),
      allowed_nodes: allowed
  end

  # Agent: project_root tells Claude CLI where to work
  if project_root = System.get_env("REVERB_PROJECT_ROOT") do
    config :reverb, Reverb.Agent, project_root: project_root
  end
end
