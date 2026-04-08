defmodule Reverb.Emitter.TelemetryHandler do
  @moduledoc """
  Attaches to configured Telemetry events and emits Reverb messages
  when exceptions or errors are observed.

  Configure which events to capture via `:telemetry_events` in
  `Reverb.Emitter` config.
  """

  alias Reverb.{Message, Emitter.Broadcaster}

  @handler_prefix "reverb-telemetry-"

  @doc "Attaches handlers for all configured telemetry events."
  def attach do
    events = configured_events()

    Enum.each(events, fn event_name ->
      handler_id = @handler_prefix <> Enum.join(event_name, "-")

      :telemetry.attach(
        handler_id,
        event_name,
        &handle_event/4,
        %{}
      )
    end)
  end

  @doc "Detaches all Reverb telemetry handlers."
  def detach do
    events = configured_events()

    Enum.each(events, fn event_name ->
      handler_id = @handler_prefix <> Enum.join(event_name, "-")

      try do
        :telemetry.detach(handler_id)
      rescue
        _ -> :ok
      end
    end)
  end

  @doc false
  def handle_event(event_name, measurements, metadata, _config) do
    kind =
      if Map.has_key?(metadata, :kind) and metadata.kind == :error, do: :error, else: :telemetry

    message_text = build_message(event_name, measurements, metadata)
    source = Enum.join(event_name, ".")

    stacktrace =
      if Map.has_key?(metadata, :stacktrace), do: Exception.format_stacktrace(metadata.stacktrace)

    message =
      Message.new(kind, message_text,
        source: source,
        stacktrace: stacktrace,
        metadata: sanitize_metadata(metadata)
      )

    Broadcaster.broadcast(message)
  end

  defp configured_events do
    Application.get_env(:reverb, Reverb.Emitter, [])
    |> Keyword.get(:telemetry_events, [])
    |> Enum.map(fn event -> Enum.map(event, &to_string/1) |> Enum.map(&String.to_atom/1) end)
  end

  defp build_message(event_name, measurements, metadata) do
    event = Enum.join(event_name, ".")

    reason =
      cond do
        Map.has_key?(metadata, :reason) -> inspect(metadata.reason, limit: 200)
        Map.has_key?(metadata, :error) -> inspect(metadata.error, limit: 200)
        true -> inspect(measurements, limit: 200)
      end

    "Telemetry [#{event}]: #{reason}"
  end

  defp sanitize_metadata(metadata) do
    metadata
    |> Map.drop([:stacktrace, :conn, :socket])
    |> Map.new(fn {k, v} -> {to_string(k), inspect(v, limit: 100)} end)
  end
end
