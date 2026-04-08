defmodule Reverb.Claims do
  @moduledoc """
  Lightweight claim registry used to prevent duplicate active work on the same
  subject.

  Claims are ephemeral coordinator state. Durable queue truth lives in Postgres,
  but claims protect against accidental double-dispatch while a task is leased.
  """

  use GenServer

  @table :reverb_claims

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec claim(String.t(), String.t(), pos_integer()) :: :ok | {:error, {:claimed, map()}}
  def claim(subject, owner, ttl_ms \\ 300_000)
      when is_binary(subject) and is_binary(owner) and ttl_ms > 0 do
    GenServer.call(__MODULE__, {:claim, subject, owner, ttl_ms})
  end

  @spec release(String.t(), String.t() | nil) :: :ok
  def release(subject, owner \\ nil) when is_binary(subject) do
    GenServer.call(__MODULE__, {:release, subject, owner})
  end

  @spec lookup(String.t()) :: {:ok, map()} | :error
  def lookup(subject) when is_binary(subject) do
    GenServer.call(__MODULE__, {:lookup, subject})
  end

  @spec claimed?(String.t()) :: boolean()
  def claimed?(subject) when is_binary(subject) do
    match?({:ok, _}, lookup(subject))
  end

  @spec reap_expired() :: non_neg_integer()
  def reap_expired do
    GenServer.call(__MODULE__, :reap_expired)
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_call({:claim, subject, owner, ttl_ms}, _from, state) do
    now = System.system_time(:millisecond)
    expires_at = now + ttl_ms

    reply =
      case current_claim(subject, now) do
        nil ->
          :ets.insert(@table, {subject, %{owner: owner, claimed_at: now, expires_at: expires_at}})
          :ok

        claim ->
          {:error, {:claimed, claim}}
      end

    {:reply, reply, state}
  end

  def handle_call({:release, subject, nil}, _from, state) do
    :ets.delete(@table, subject)
    {:reply, :ok, state}
  end

  def handle_call({:release, subject, owner}, _from, state) do
    case current_claim(subject, System.system_time(:millisecond)) do
      %{owner: ^owner} -> :ets.delete(@table, subject)
      _ -> :ok
    end

    {:reply, :ok, state}
  end

  def handle_call({:lookup, subject}, _from, state) do
    reply =
      case current_claim(subject, System.system_time(:millisecond)) do
        nil -> :error
        claim -> {:ok, claim}
      end

    {:reply, reply, state}
  end

  def handle_call(:reap_expired, _from, state) do
    now = System.system_time(:millisecond)

    count =
      @table
      |> :ets.tab2list()
      |> Enum.count(fn {subject, claim} ->
        if claim.expires_at <= now do
          :ets.delete(@table, subject)
          true
        else
          false
        end
      end)

    {:reply, count, state}
  end

  defp current_claim(subject, now) do
    case :ets.lookup(@table, subject) do
      [{^subject, claim}] when claim.expires_at > now ->
        claim

      [{^subject, _expired}] ->
        :ets.delete(@table, subject)
        nil

      [] ->
        nil
    end
  end
end
