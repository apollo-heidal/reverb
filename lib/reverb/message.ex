defmodule Reverb.Message do
  @moduledoc """
  Struct representing a message emitted from a production app.

  Messages are broadcast over PubSub and received by the dev-side listener.
  They carry error/warning/manual context that the triage system converts
  into actionable tasks.
  """

  @enforce_keys [:kind, :message]
  defstruct [
    :id,
    :kind,
    :message,
    :source,
    :stacktrace,
    :severity,
    :node,
    :timestamp,
    metadata: %{},
    version: 1
  ]

  @type kind :: :error | :warning | :manual | :telemetry
  @type severity :: :critical | :high | :medium | :low

  @type t :: %__MODULE__{
          id: String.t() | nil,
          kind: kind(),
          message: String.t(),
          source: String.t() | nil,
          stacktrace: String.t() | nil,
          metadata: map(),
          severity: severity(),
          node: atom() | nil,
          timestamp: DateTime.t() | nil,
          version: pos_integer()
        }

  @doc "Builds a new message with auto-generated id, timestamp, and node."
  def new(kind, message, opts \\ []) when kind in [:error, :warning, :manual, :telemetry] do
    %__MODULE__{
      id: generate_id(),
      kind: kind,
      message: to_string(message),
      source: Keyword.get(opts, :source),
      stacktrace: Keyword.get(opts, :stacktrace),
      metadata: Keyword.get(opts, :metadata, %{}),
      severity: Keyword.get(opts, :severity) || infer_severity(kind),
      node: node(),
      timestamp: DateTime.utc_now()
    }
  end

  @doc "Computes a fingerprint for deduplication."
  def fingerprint(%__MODULE__{} = msg) do
    data = "#{msg.kind}:#{msg.source}:#{normalize_message(msg.message)}"
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower) |> binary_part(0, 16)
  end

  defp generate_id do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)
    <<u0::48, 4::4, u1::12, 2::2, u2::62>> |> Ecto.UUID.load!()
  end

  defp infer_severity(:error), do: :high
  defp infer_severity(:warning), do: :medium
  defp infer_severity(:manual), do: :medium
  defp infer_severity(:telemetry), do: :medium

  defp normalize_message(msg) when is_binary(msg) do
    # Strip dynamic parts (PIDs, refs, timestamps, hex addresses) for stable fingerprints
    msg
    |> String.replace(~r/#PID<[\d.]+>/, "#PID<...>")
    |> String.replace(~r/#Reference<[\d.]+>/, "#Ref<...>")
    |> String.replace(~r/0x[0-9a-fA-F]+/, "0x...")
    |> String.replace(~r/\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}/, "TIMESTAMP")
  end
end
