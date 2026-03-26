defmodule Reverb do
  @moduledoc """
  Reverb — production error reverberation for BEAM apps.

  Bridges production apps to dev-side AI agents via BEAM distribution.
  Production apps emit error messages over PubSub; a dev-side companion
  captures them, triages into tasks, and queues them for an agent loop.

  ## Usage

  Add to your app as a dependency:

      {:reverb, path: "../reverb"}

  Configure in prod:

      config :reverb,
        mode: :emitter,
        topic_hash: "my-app-prod",
        pubsub_name: MyApp.PubSub

  Configure in dev:

      config :reverb,
        mode: :receiver,
        topic_hash: "my-app-prod",
        pubsub_name: MyApp.PubSub

  ## Manual Emission

      Reverb.emit(:error, "Payment processing failed", metadata: %{order_id: 123})
      Reverb.emit(:warning, "Slow query detected", source: "MyApp.Repo")
      Reverb.emit(:manual, "Review this user flow")
  """

  alias Reverb.{Message, Emitter.Broadcaster}

  @doc """
  Emits a Reverb message from the current node.

  Only works in `:emitter` mode. No-op otherwise.

  ## Options

  - `:source` — origin (e.g., "MyModule.my_func/2:42")
  - `:stacktrace` — formatted stacktrace string
  - `:metadata` — arbitrary map of context
  - `:severity` — `:critical | :high | :medium | :low`
  """
  def emit(kind, message, opts \\ [])

  def emit(kind, message, opts) when kind in [:error, :warning, :manual, :telemetry] do
    if Application.get_env(:reverb, :mode) == :emitter do
      msg = Message.new(kind, message, opts)
      Broadcaster.broadcast(msg)
    else
      :ok
    end
  end

  @doc "Returns the agent loop status. Only works in `:receiver` mode."
  def status do
    if Process.whereis(Reverb.Agent.Loop) do
      Reverb.Agent.Loop.status()
    else
      %{alive: false, status: :disabled}
    end
  end

  @doc "Pauses the agent loop."
  def pause do
    if Process.whereis(Reverb.Agent.Loop),
      do: Reverb.Agent.Loop.pause(),
      else: {:error, :not_running}
  end

  @doc "Resumes the agent loop."
  def resume do
    if Process.whereis(Reverb.Agent.Loop),
      do: Reverb.Agent.Loop.resume(),
      else: {:error, :not_running}
  end
end
