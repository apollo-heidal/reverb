defmodule Reverb.Runtime do
  @moduledoc """
  In-memory runtime projection for scheduler state and recent coordinator
  events.

  This is intentionally local to the coordinator VM. Steering surfaces can read
  from it without conflating runtime projections with durable queue truth.
  """

  use GenServer

  @topic "runtime:events"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def events_topic, do: @topic

  @spec snapshot() :: map()
  def snapshot do
    GenServer.call(__MODULE__, :snapshot)
  end

  @spec scheduler_status(map()) :: :ok
  def scheduler_status(attrs) when is_map(attrs) do
    GenServer.cast(__MODULE__, {:scheduler_status, attrs})
  end

  @spec agent_status(String.t(), map()) :: :ok
  def agent_status(agent_id, attrs) when is_binary(agent_id) and is_map(attrs) do
    GenServer.cast(__MODULE__, {:agent_status, agent_id, attrs})
  end

  @spec record_event(atom(), map()) :: :ok
  def record_event(kind, attrs \\ %{}) when is_atom(kind) and is_map(attrs) do
    GenServer.cast(__MODULE__, {:record_event, kind, attrs})
  end

  @impl true
  def init(_opts) do
    {:ok,
     %{
       scheduler: %{status: :booting, updated_at: DateTime.utc_now()},
       agents: %{},
       events: []
     }}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:scheduler_status, attrs}, state) do
    scheduler = Map.merge(state.scheduler, attrs) |> Map.put(:updated_at, DateTime.utc_now())
    state = %{state | scheduler: scheduler}
    broadcast({:scheduler_status, scheduler})
    {:noreply, state}
  end

  def handle_cast({:agent_status, agent_id, attrs}, state) do
    payload =
      Map.merge(Map.get(state.agents, agent_id, %{}), attrs)
      |> Map.put(:updated_at, DateTime.utc_now())

    agents = Map.put(state.agents, agent_id, payload)
    state = %{state | agents: agents}
    broadcast({:agent_status, agent_id, payload})
    {:noreply, state}
  end

  def handle_cast({:record_event, kind, attrs}, state) do
    event = %{kind: kind, attrs: attrs, at: DateTime.utc_now()}

    max_events =
      Application.get_env(:reverb, Reverb.Scheduler, []) |> Keyword.get(:max_events, 200)

    events = [event | state.events] |> Enum.take(max_events)
    state = %{state | events: events}
    broadcast({:runtime_event, event})
    {:noreply, state}
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(Reverb.LocalPubSub, @topic, message)
  end
end
