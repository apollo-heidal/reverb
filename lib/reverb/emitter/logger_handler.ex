defmodule Reverb.Emitter.LoggerHandler do
  @moduledoc """
  Elixir Logger handler that intercepts error/warning log events and
  emits them as Reverb messages.

  Attaches via `Logger.add_handler/3` (Elixir 1.15+). Configure which
  log levels to capture via `:levels` in `Reverb.Emitter` config.

  ## Setup

  Called automatically by `Reverb.Application` when `mode: :emitter` and
  `logger_handler: true`.
  """

  alias Reverb.{Message, Emitter.Broadcaster}

  @handler_id :reverb_logger

  @doc "Attaches the handler to the Erlang logger."
  def attach do
    config = %{levels: configured_levels()}

    :logger.add_handler(@handler_id, __MODULE__, %{
      config: config,
      level: :all,
      filters: [],
      filter_default: :log
    })
  end

  @doc "Detaches the handler."
  def detach do
    :logger.remove_handler(@handler_id)
  end

  # :logger handler callbacks

  @doc false
  def log(%{level: level, msg: msg} = event, _config) do
    if level in configured_levels() do
      message_text = format_message(msg)
      source = extract_source(event)
      stacktrace = extract_stacktrace(event)

      kind = if level in [:error, :critical, :alert, :emergency], do: :error, else: :warning

      message = Message.new(kind, message_text, source: source, stacktrace: stacktrace)
      Broadcaster.broadcast(message)
    end
  end

  def adding_handler(config), do: {:ok, config}
  def removing_handler(_config), do: :ok
  def changing_config(_action, _old, new), do: {:ok, new}

  defp configured_levels do
    Application.get_env(:reverb, Reverb.Emitter, [])
    |> Keyword.get(:levels, [:error, :warning])
  end

  defp format_message({:string, msg}), do: to_string(msg)
  defp format_message({:report, report}), do: inspect(report, limit: 500)
  defp format_message({format, args}) when is_list(args), do: :io_lib.format(format, args) |> to_string()
  defp format_message(other), do: inspect(other, limit: 500)

  defp extract_source(%{meta: %{mfa: {m, f, a}}}), do: "#{inspect(m)}.#{f}/#{a}"
  defp extract_source(%{meta: %{file: file, line: line}}), do: "#{file}:#{line}"
  defp extract_source(_), do: nil

  defp extract_stacktrace(%{meta: %{crash_reason: {_, stacktrace}}}) when is_list(stacktrace) do
    Exception.format_stacktrace(stacktrace)
  end

  defp extract_stacktrace(_), do: nil
end
