defmodule Reverb.Agent.Runner do
  @moduledoc """
  Manages an external agent process (e.g., Claude CLI) via an Erlang Port.

  Extracted from the heartbeat system. Handles:
  - Port lifecycle (open, close, timeout)
  - Stdout buffering (capped at 50KB)
  - Exit status detection
  """

  @max_buffer_size 51_200

  @doc """
  Opens a port to the configured agent command with the given prompt.

  Returns `{port, timeout_ref}`.
  """
  def open_port(prompt, config) do
    command = to_charlist(config.agent_command)
    args = config.agent_args ++ ["--", prompt]
    project_root = config.project_root || File.cwd!()
    home = System.get_env("HOME") || "/root"

    port =
      Port.open({:spawn_executable, command}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: Enum.map(args, &to_charlist/1),
        cd: to_charlist(project_root),
        env: [
          {~c"PATH", to_charlist("/usr/bin:/bin:#{home}/.local/bin:#{System.get_env("PATH")}")},
          {~c"HOME", to_charlist(home)}
        ]
      ])

    timeout_ref = Process.send_after(self(), :task_timeout, config.task_timeout_ms)

    {port, timeout_ref}
  end

  @doc "Appends data to the output buffer, capping at #{@max_buffer_size} bytes."
  def append_buffer(buffer, data) do
    new_buffer = buffer <> data

    if byte_size(new_buffer) > @max_buffer_size do
      binary_part(new_buffer, byte_size(new_buffer) - @max_buffer_size, @max_buffer_size)
    else
      new_buffer
    end
  end

  @doc "Closes a port safely."
  def close_port(nil), do: :ok

  def close_port(port) do
    Port.close(port)
    :ok
  rescue
    _ -> :ok
  end
end
