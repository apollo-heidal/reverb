import Config

split_env_list = fn
  nil -> nil
  value -> String.split(value, ";;", trim: true)
end

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

  agent_overrides =
    []
    |> then(fn overrides ->
      case System.get_env("REVERB_AGENT_ADAPTER") do
        nil -> overrides
        value -> Keyword.put(overrides, :agent_adapter, String.to_atom(value))
      end
    end)
    |> then(fn overrides ->
      case System.get_env("REVERB_AGENT_COMMAND") do
        nil -> overrides
        value -> Keyword.put(overrides, :agent_command, value)
      end
    end)
    |> then(fn overrides ->
      case split_env_list.(System.get_env("REVERB_AGENT_ARGS")) do
        nil -> overrides
        value -> Keyword.put(overrides, :agent_args, value)
      end
    end)
    |> then(fn overrides ->
      case System.get_env("REVERB_AGENT_MAX_AGENTS") do
        nil -> overrides
        value -> Keyword.put(overrides, :max_agents, String.to_integer(value))
      end
    end)

  if agent_overrides != [] do
    config :reverb, Reverb.Agent, agent_overrides
  end

  workspace_overrides =
    []
    |> then(fn overrides ->
      case System.get_env("REVERB_WORKSPACE_ROOT") do
        nil -> overrides
        value -> Keyword.put(overrides, :root, value)
      end
    end)
    |> then(fn overrides ->
      case System.get_env("REVERB_WORKSPACE_REPO_ROOT") do
        nil -> overrides
        value -> Keyword.put(overrides, :repo_root, value)
      end
    end)
    |> then(fn overrides ->
      case System.get_env("REVERB_WORKSPACE_SOURCE_REF") do
        nil -> overrides
        value -> Keyword.put(overrides, :source_ref, value)
      end
    end)

  if workspace_overrides != [] do
    config :reverb, Reverb.Workspaces, workspace_overrides
  end

  if commands = split_env_list.(System.get_env("REVERB_VALIDATION_COMMANDS")) do
    config :reverb, Reverb.Validation, commands: commands
  end
end
