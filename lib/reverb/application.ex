defmodule Reverb.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    mode = Application.get_env(:reverb, :mode, :disabled)
    Logger.info("[Reverb] Starting in #{mode} mode")

    children = base_children(mode) ++ mode_children(mode)

    opts = [strategy: :one_for_one, name: Reverb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp base_children(:receiver) do
    pubsub = Application.get_env(:reverb, :pubsub_name)
    start_pubsub? = Application.get_env(:reverb, :start_pubsub, false)

    pubsub_child =
      if pubsub && start_pubsub? do
        Logger.info("[Reverb] Starting PubSub #{inspect(pubsub)} (standalone receiver)")
        [{Phoenix.PubSub, name: pubsub}]
      else
        []
      end

    pubsub_child ++ [Reverb.Repo]
  end

  defp base_children(_) do
    # In test, always start Repo for sandbox/migration support
    if repo_configured?(), do: [Reverb.Repo], else: []
  end

  defp repo_configured? do
    Application.get_env(:reverb, Reverb.Repo) != nil and
      Application.get_env(:reverb, Reverb.Repo)[:pool] != nil
  end

  defp mode_children(:emitter) do
    emitter_config = Application.get_env(:reverb, Reverb.Emitter, [])

    if Keyword.get(emitter_config, :logger_handler, false) do
      Reverb.Emitter.LoggerHandler.attach()
    end

    if Keyword.get(emitter_config, :telemetry_events, []) != [] do
      Reverb.Emitter.TelemetryHandler.attach()
    end

    # Emitter has no supervised children (handlers are global)
    []
  end

  defp mode_children(:receiver) do
    agent_config = Application.get_env(:reverb, Reverb.Agent, [])

    receiver_children = [
      Reverb.Receiver.Guard,
      Reverb.Receiver.Listener
    ]

    agent_children =
      if Keyword.get(agent_config, :enabled, false) do
        [Reverb.Agent.Loop]
      else
        []
      end

    receiver_children ++ agent_children
  end

  defp mode_children(_), do: []
end
