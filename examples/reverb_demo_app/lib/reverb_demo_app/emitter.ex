defmodule ReverbDemoApp.Emitter do
  @moduledoc """
  Emits one trivial feature request at a time into Reverb.
  """

  use GenServer
  require Logger

  alias ReverbDemoApp.FeatureBacklog

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %{
      interval_ms: Application.get_env(:reverb_demo_app, :emit_interval_ms, 30_000),
      repeat?: Application.get_env(:reverb_demo_app, :repeat_backlog, false),
      source: Application.get_env(:reverb_demo_app, :source_name, "ReverbDemoApp.Emitter"),
      backlog: FeatureBacklog.items(),
      index: 0
    }

    send(self(), :emit_next)
    {:ok, state}
  end

  @impl true
  def handle_info(:emit_next, %{backlog: backlog, index: index} = state)
      when index < length(backlog) do
    item = Enum.at(backlog, index)
    Logger.info("[ReverbDemoApp] emitting #{item.id}")

    :ok =
      Reverb.emit(:manual, item.body,
        source: state.source,
        metadata: item |> stringify_keys() |> Map.put("feature_id", item.id)
      )

    Process.send_after(self(), :emit_next, state.interval_ms)
    {:noreply, %{state | index: index + 1}}
  end

  def handle_info(:emit_next, %{repeat?: true, backlog: backlog} = state) do
    Process.send_after(self(), :emit_next, state.interval_ms)
    {:noreply, %{state | index: rem(state.index, max(length(backlog), 1))}}
  end

  def handle_info(:emit_next, state) do
    Logger.info("[ReverbDemoApp] backlog exhausted")
    {:noreply, state}
  end

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end
end
