defmodule Reverb.RateLimiter do
  @moduledoc """
  ETS-based rate limiter for controlling message processing throughput.

  No Plug dependency — a plain module usable from any context.
  """

  @table __MODULE__
  @default_window_seconds 60
  @default_max_per_window 10

  @doc "Initializes the ETS table. Safe to call multiple times."
  def init do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    end

    :ok
  end

  @doc """
  Checks if the given key is over the rate limit.

  Returns `true` if the key has exceeded the limit.
  """
  def over_limit?(key, opts \\ []) do
    init()
    max = Keyword.get(opts, :max, @default_max_per_window)
    window = Keyword.get(opts, :window_seconds, @default_window_seconds)
    now = System.system_time(:second)

    case :ets.lookup(@table, key) do
      [{^key, {window_start, count}}] when now - window_start < window ->
        count >= max

      _ ->
        false
    end
  end

  @doc "Records a request for the given key."
  def record(key, opts \\ []) do
    init()
    window = Keyword.get(opts, :window_seconds, @default_window_seconds)
    now = System.system_time(:second)

    case :ets.lookup(@table, key) do
      [{^key, {window_start, count}}] when now - window_start < window ->
        :ets.insert(@table, {key, {window_start, count + 1}})

      _ ->
        :ets.insert(@table, {key, {now, 1}})
    end

    :ok
  end

  @doc "Checks and records in one call. Returns `:ok` or `{:error, :rate_limited}`."
  def check_and_record(key, opts \\ []) do
    if over_limit?(key, opts) do
      {:error, :rate_limited}
    else
      record(key, opts)
      :ok
    end
  end
end
