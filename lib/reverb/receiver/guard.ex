defmodule Reverb.Receiver.Guard do
  @moduledoc """
  Monitors BEAM node connections and disconnects any node not in the
  configured allowlist. Provides a safety layer for the one-way pipe
  architecture.

  In receiver mode, only the configured prod node(s) should connect.
  Any other connection is rejected.
  """

  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    allowed = Application.get_env(:reverb, Reverb.Receiver, []) |> Keyword.get(:allowed_nodes, [])
    :net_kernel.monitor_nodes(true)
    {:ok, %{allowed_nodes: MapSet.new(allowed)}}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    if MapSet.size(state.allowed_nodes) > 0 and not MapSet.member?(state.allowed_nodes, node) do
      Logger.warning("[Reverb.Guard] Unauthorized node connected: #{node}, disconnecting")
      Node.disconnect(node)
    end

    {:noreply, state}
  end

  def handle_info({:nodedown, _node}, state) do
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
