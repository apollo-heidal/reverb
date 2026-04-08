defmodule Reverb.Workspaces.PathSafetyTest do
  use ExUnit.Case, async: true

  alias Reverb.Workspaces.PathSafety

  test "accepts nested workspace paths" do
    assert {:ok, "/tmp/reverb/workspaces/task-1"} =
             PathSafety.validate("/tmp/reverb/workspaces/task-1", "/tmp/reverb/workspaces")
  end

  test "rejects the root itself" do
    assert {:error, :workspace_root_not_allowed} =
             PathSafety.validate("/tmp/reverb/workspaces", "/tmp/reverb/workspaces")
  end

  test "rejects paths outside the root" do
    assert {:error, {:outside_workspace_root, _, _}} =
             PathSafety.validate("/tmp/other/task-1", "/tmp/reverb/workspaces")
  end
end
