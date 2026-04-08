defmodule Reverb.Runs.Run do
  @moduledoc """
  Durable record of a concrete execution attempt for a task.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  @status_values [:queued, :running, :validating, :succeeded, :failed, :cancelled]

  schema "reverb_runs" do
    field(:task_id, :binary_id)
    field(:status, Ecto.Enum, values: @status_values, default: :queued)
    field(:assigned_agent, :string)
    field(:branch_name, :string)
    field(:workspace_path, :string)
    field(:agent_output, :string)
    field(:validation_output, :string)
    field(:last_error, :string)
    field(:pr_url, :string)
    field(:remote_ref, :string)
    field(:started_at, :utc_datetime)
    field(:finished_at, :utc_datetime)
    field(:metadata, :map, default: %{})

    timestamps(type: :utc_datetime)
  end

  def status_values, do: @status_values

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :task_id,
      :status,
      :assigned_agent,
      :branch_name,
      :workspace_path,
      :agent_output,
      :validation_output,
      :last_error,
      :pr_url,
      :remote_ref,
      :started_at,
      :finished_at,
      :metadata
    ])
    |> validate_required([:task_id, :status])
    |> validate_length(:assigned_agent, max: 255)
    |> validate_length(:branch_name, max: 255)
    |> validate_length(:workspace_path, max: 4096)
    |> validate_length(:pr_url, max: 2048)
    |> validate_length(:remote_ref, max: 1024)
  end
end
