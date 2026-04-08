defmodule Reverb.Workspaces.Slot do
  @moduledoc """
  Runtime descriptor for a checked-out workspace.
  """

  @enforce_keys [:id, :path, :branch]
  defstruct [:id, :path, :branch, :task_id, status: :available]
end
