defmodule Reverb.Agent.Worker do
  @moduledoc """
  Executes a single task attempt inside a coordinator-managed workspace.
  """

  alias Reverb.{Git, Runs, Tasks, Validation}

  def perform(%Tasks.Task{} = task, agent_id, config)
      when is_binary(agent_id) and is_map(config) do
    case Reverb.Workspaces.Pool.checkout(task, branch: Git.task_branch(task)) do
      {:ok, slot} ->
        try do
          with {:ok, run} <-
                 Runs.create_run(%{
                   task_id: task.id,
                   assigned_agent: agent_id,
                   branch_name: slot.branch,
                   workspace_path: slot.path,
                   status: :queued
                 }),
               {:ok, task} <-
                 Tasks.mark_running(task, %{
                   assigned_agent: agent_id,
                   branch_name: slot.branch,
                   workspace_path: slot.path,
                   current_run_id: run.id
                 }),
               {:ok, run} <- Runs.mark_running(run),
               {:ok, result} <- execute_agent(task, slot.path, config),
               :ok <- Git.commit_all(slot.path, commit_message(task)),
               {:ok, run} <- Runs.mark_validating(run, %{agent_output: result.output}),
               {:ok, _task} <- Tasks.mark_validating(task),
               {:ok, validation_output} <- Validation.run(slot.path, validation_opts(task)),
               {:ok, pr_url, remote_status} <- maybe_publish(slot.branch, task),
               {:ok, run} <-
                 Runs.mark_finished(run, :succeeded, %{
                   validation_output: validation_output,
                   pr_url: pr_url
                 }),
               {:ok, task} <-
                 Tasks.mark_stable(task, %{
                   remote_status: remote_status,
                   done_note: success_note(pr_url)
                 }) do
            %{
              status: :succeeded,
              task_id: task.id,
              run_id: run.id,
              subject: subject_for(task),
              agent_id: agent_id,
              branch_name: slot.branch,
              workspace_path: slot.path,
              output: result.output,
              validation_output: validation_output,
              pr_url: pr_url,
              remote_status: remote_status
            }
          else
            {:error, {:exit_code, _code, result}} ->
              fail(task, agent_id, result.output)

            {:error, :timeout} ->
              fail(task, agent_id, "agent execution timed out")

            {:error, %{combined_output: output}} ->
              fail(task, agent_id, output)

            {:error, reason} ->
              fail(task, agent_id, inspect(reason))
          end
        after
          _ = Reverb.Workspaces.Pool.checkin_by_path(slot.path)
        end

      {:error, reason} ->
        fail(task, agent_id, inspect(reason))
    end
  end

  defp execute_agent(task, cwd, config) do
    prompt = build_task_prompt(task, cwd)

    Reverb.Agent.CLI.run(prompt,
      adapter: Map.get(config, :agent_adapter, :generic),
      command: config.agent_command,
      args: config.agent_args,
      cwd: cwd,
      timeout_ms: config.task_timeout_ms,
      env: [
        {"HOME", System.get_env("HOME") || "/tmp"},
        {"PATH", System.get_env("PATH") || "/usr/bin:/bin"}
      ]
    )
  end

  defp maybe_publish(branch, task) do
    if remote_enabled?() do
      with :ok <- Git.push_branch(branch),
           {:ok, pr_url} <- Git.open_or_update_pr(branch, pr_title(task), pr_body(task)) do
        {:ok, pr_url, :pr_opened}
      end
    else
      {:ok, nil, :local_only}
    end
  end

  defp fail(task, agent_id, reason) do
    current_run =
      case task.current_run_id do
        nil -> nil
        id -> Runs.get_run(id)
      end

    if current_run, do: Runs.mark_finished(current_run, :failed, %{last_error: reason})
    _ = Tasks.mark_failed(task, reason, %{assigned_agent: agent_id})

    %{
      status: :failed,
      task_id: task.id,
      run_id: task.current_run_id,
      subject: subject_for(task),
      agent_id: agent_id,
      error: reason
    }
  end

  defp build_task_prompt(task, workspace_path) do
    """
    You are operating inside a coordinator-managed isolated workspace.

    Workspace: #{workspace_path}
    Task ID: #{task.id}
    Subject: #{task.subject || "n/a"}
    Feature ID: #{metadata_value(task, "feature_id") || "n/a"}
    Expected Files: #{format_list(metadata_value(task, "expected_files"))}
    Validation Commands: #{format_list(task_validation_commands(task) || default_validation_commands())}

    Requirements:
    - Make changes only inside this workspace.
    - Do not switch branches.
    - Do not push or merge branches yourself.
    - Keep output concise and action-oriented.

    Task:
    #{task.body}

    Steering Notes:
    #{task.steering_notes || "None"}

    Task Metadata JSON:
    #{Jason.encode!(task.metadata || %{})}
    """
  end

  defp commit_message(task) do
    "reverb: #{String.slice(task.body, 0, 72)}"
  end

  defp pr_title(task) do
    "reverb: #{String.slice(task.body, 0, 72)}"
  end

  defp pr_body(task) do
    """
    Generated by Reverb.

    Task ID: #{task.id}
    Subject: #{task.subject || "n/a"}
    """
  end

  defp success_note(nil), do: "Validated locally"
  defp success_note(pr_url), do: "Validated locally and opened PR: #{pr_url}"

  defp remote_enabled? do
    config = Application.get_env(:reverb, Reverb.Git, [])
    Keyword.get(config, :remote_enabled, false) and Keyword.get(config, :push_enabled, false)
  end

  defp subject_for(task) do
    task.subject || task.fingerprint || "task:#{task.id}"
  end

  defp validation_opts(task) do
    case task_validation_commands(task) do
      nil -> []
      commands -> [commands: commands]
    end
  end

  defp task_validation_commands(task) do
    case metadata_value(task, "validation_commands") || metadata_value(task, "validation") do
      nil -> nil
      [] -> nil
      commands -> commands
    end
  end

  defp default_validation_commands do
    Application.get_env(:reverb, Reverb.Validation, [])
    |> Keyword.get(:commands, [])
  end

  defp metadata_value(task, key) do
    case task.metadata || %{} do
      %{^key => value} -> value
      _ -> nil
    end
  end

  defp format_list(values) when is_list(values), do: Enum.join(values, ", ")
  defp format_list(nil), do: "n/a"
  defp format_list(value), do: to_string(value)
end
