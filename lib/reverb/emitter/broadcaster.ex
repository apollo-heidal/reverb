defmodule Reverb.Emitter.Broadcaster do
  @moduledoc """
  Thin wrapper around Phoenix.PubSub.broadcast/3 for emitting Reverb messages.

  Used by the LoggerHandler, TelemetryHandler, and the public `Reverb.emit/3` API.
  """

  alias Reverb.{Message, Topic}

  @doc "Broadcasts a Reverb.Message to the configured PubSub topic."
  def broadcast(%Message{} = message) do
    Phoenix.PubSub.broadcast(
      Topic.pubsub_name(),
      Topic.name(),
      {:reverb_message, message}
    )
  end
end
