defmodule Reverb.Workspaces.PathSafety do
  @moduledoc """
  Prevents coordinator-managed workspaces from escaping the configured sandbox
  root.
  """

  @spec validate(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def validate(path, root) when is_binary(path) and is_binary(root) do
    expanded_path = Path.expand(path)
    expanded_root = Path.expand(root)

    cond do
      String.trim(path) == "" ->
        {:error, :empty_workspace_path}

      expanded_path == expanded_root ->
        {:error, :workspace_root_not_allowed}

      String.starts_with?(expanded_path <> "/", expanded_root <> "/") ->
        {:ok, expanded_path}

      true ->
        {:error, {:outside_workspace_root, expanded_path, expanded_root}}
    end
  end
end
