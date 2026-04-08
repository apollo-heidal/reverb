defmodule Reverb.Validation do
  @moduledoc """
  Runs coordinator-managed validation commands inside an isolated workspace.
  """

  @spec run(String.t(), keyword()) :: {:ok, String.t()} | {:error, map()}
  def run(cwd, opts \\ []) when is_binary(cwd) do
    commands =
      Keyword.get(opts, :commands) ||
        Application.get_env(:reverb, Reverb.Validation, []) |> Keyword.get(:commands, [])

    env =
      Keyword.get(opts, :env) ||
        Application.get_env(:reverb, Reverb.Validation, [])
        |> Keyword.get(:env, %{})
        |> Enum.to_list()

    Enum.reduce_while(commands, {:ok, []}, fn command, {:ok, outputs} ->
      case System.cmd("/bin/sh", ["-lc", command], cd: cwd, stderr_to_stdout: true, env: env) do
        {output, 0} ->
          {:cont, {:ok, [format_output(command, output) | outputs]}}

        {output, code} ->
          {:halt,
           {:error,
            %{
              command: command,
              exit_code: code,
              output: String.trim(output),
              combined_output:
                Enum.reverse([format_output(command, output) | outputs]) |> Enum.join("\n\n")
            }}}
      end
    end)
    |> case do
      {:ok, outputs} -> {:ok, Enum.reverse(outputs) |> Enum.join("\n\n")}
      {:error, _} = error -> error
    end
  end

  defp format_output(command, output) do
    "$ #{command}\n" <> String.trim(output)
  end
end
