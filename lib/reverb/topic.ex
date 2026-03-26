defmodule Reverb.Topic do
  @moduledoc """
  Derives the PubSub topic name from the configured topic hash.

  Both the emitter (prod) and receiver (dev) must share the same `topic_hash`
  config value to communicate on the same PubSub topic.
  """

  @doc "Returns the PubSub topic string for Reverb messages."
  def name do
    hash = Application.get_env(:reverb, :topic_hash, "default")
    "reverb:#{short_hash(hash)}"
  end

  @doc "Returns the configured PubSub server name."
  def pubsub_name do
    Application.get_env(:reverb, :pubsub_name) ||
      raise "Reverb requires :pubsub_name to be configured"
  end

  defp short_hash(input) do
    :crypto.hash(:sha256, to_string(input))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 12)
  end
end
