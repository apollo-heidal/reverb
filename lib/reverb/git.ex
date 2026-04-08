defmodule Reverb.Git do
  @moduledoc """
  Coordinator-owned git boundary.

  Agents operate inside coordinator-managed workspaces, but all branch and
  remote decisions are enforced here.
  """

  require Logger

  alias Reverb.Tasks.Task

  @default_commit_message "reverb: autonomous change"

  def git_available? do
    not is_nil(System.find_executable("git"))
  end

  def task_branch(%Task{} = task) do
    explicit_branch(task) ||
      "reverb/task-#{String.slice(task.id || Ecto.UUID.generate(), 0, 8)}-#{slug(task.subject || task.body)}"
  end

  def prepare_workspace(%Task{} = task, opts) do
    with true <- git_available?() || {:error, :git_not_available},
         repo_root when is_binary(repo_root) <-
           repo_root() || {:error, :repo_root_not_configured},
         path when is_binary(path) <-
           Keyword.get(opts, :path) || {:error, :workspace_path_required},
         branch when is_binary(branch) <- Keyword.get(opts, :branch, task_branch(task)),
         :ok <- ensure_branch_allowed(branch),
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- remove_existing_worktree(path, repo_root),
         {_, 0} <-
           System.cmd("git", ["worktree", "add", "-B", branch, path, source_ref()],
             cd: repo_root,
             stderr_to_stdout: true
           ) do
      {:ok, %{path: path, branch: branch}}
    else
      {output, code} when is_binary(output) ->
        {:error, {:git_failed, code, String.trim(output)}}

      {:error, _} = error ->
        error

      false ->
        {:error, :git_not_available}

      other ->
        {:error, other}
    end
  end

  def cleanup_workspace(path) when is_binary(path) do
    case repo_root() do
      nil ->
        File.rm_rf(path)
        :ok

      repo_root ->
        if File.exists?(path) do
          case System.cmd("git", ["worktree", "remove", "--force", path],
                 cd: repo_root,
                 stderr_to_stdout: true
               ) do
            {_, 0} ->
              :ok

            {output, code} ->
              Logger.warning(
                "[Reverb.Git] failed to remove worktree #{path} (#{code}): #{String.trim(output)}"
              )

              File.rm_rf(path)
              :ok
          end
        else
          :ok
        end
    end
  end

  def status(path) when is_binary(path) do
    run_git(path, ["status", "--short"])
  end

  def commit_all(path, message \\ @default_commit_message) when is_binary(path) do
    with :ok <- run_git_ok(path, ["add", "-A"]),
         :ok <-
           run_git_ok(path, [
             "-c",
             "user.name=Reverb",
             "-c",
             "user.email=reverb@noreply.invalid",
             "commit",
             "--allow-empty",
             "-m",
             message
           ]) do
      :ok
    end
  end

  def push_branch(branch) when is_binary(branch) do
    with :ok <- ensure_remote_push_enabled(),
         :ok <- ensure_branch_allowed(branch),
         repo_root when is_binary(repo_root) <-
           repo_root() || {:error, :repo_root_not_configured},
         :ok <- run_git_ok(repo_root, ["push", remote_name(), branch]) do
      :ok
    end
  end

  def open_or_update_pr(branch, title, body) when is_binary(branch) do
    with :ok <- ensure_remote_push_enabled(),
         true <- System.find_executable("gh") != nil || {:error, :gh_not_available},
         :ok <- ensure_branch_allowed(branch) do
      case System.cmd("gh", ["pr", "create", "--head", branch, "--title", title, "--body", body],
             stderr_to_stdout: true
           ) do
        {output, 0} -> {:ok, String.trim(output)}
        {output, code} -> {:error, {:gh_failed, code, String.trim(output)}}
      end
    else
      false -> {:error, :gh_not_available}
      {:error, _} = error -> error
    end
  end

  def ensure_branch_allowed(branch) when is_binary(branch) do
    protected =
      Application.get_env(:reverb, Reverb.Git, [])
      |> Keyword.get(:protected_branches, ["main", "master"])

    if branch in protected do
      {:error, {:protected_branch, branch}}
    else
      :ok
    end
  end

  defp explicit_branch(%Task{branch_name: branch}) when is_binary(branch) and branch != "",
    do: branch

  defp explicit_branch(_task), do: nil

  defp ensure_remote_push_enabled do
    config = Application.get_env(:reverb, Reverb.Git, [])

    if Keyword.get(config, :remote_enabled, false) and Keyword.get(config, :push_enabled, false) do
      :ok
    else
      {:error, :remote_push_disabled}
    end
  end

  defp remove_existing_worktree(path, repo_root) do
    if File.exists?(path) do
      cleanup_workspace(path)
    else
      _ = repo_root
      :ok
    end
  end

  defp run_git(path, args) do
    case System.cmd("git", args, cd: path, stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, code} -> {:error, {:git_failed, code, String.trim(output)}}
    end
  end

  defp run_git_ok(path, args) do
    case run_git(path, args) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp source_ref do
    Application.get_env(:reverb, Reverb.Workspaces, [])
    |> Keyword.get(:source_ref, "HEAD")
  end

  defp repo_root do
    Application.get_env(:reverb, Reverb.Workspaces, [])
    |> Keyword.get(:repo_root)
  end

  defp remote_name do
    Application.get_env(:reverb, Reverb.Git, [])
    |> Keyword.get(:remote_name, "origin")
  end

  defp slug(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> String.slice(0, 32)
  end
end
