defmodule Reverb.Tasks.Task do
  @moduledoc """
  Ecto schema for Reverb tasks — the unit of work for the agent loop.

  Generalized from app-specific feedback: no foreign keys, uses `source_id`
  (free-form string) instead of a user reference. Includes `fingerprint` for
  error deduplication and `severity` for triage prioritization.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  @status_values [:new, :todo, :worked_on, :done]
  @severity_values [:critical, :high, :medium, :low]

  schema "reverb_tasks" do
    field :body, :string
    field :category, :string
    field :source_id, :string
    field :fingerprint, :string
    field :error_count, :integer, default: 1
    field :severity, Ecto.Enum, values: @severity_values, default: :medium
    field :status, Ecto.Enum, values: @status_values, default: :new
    field :done_note, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def status_values, do: @status_values
  def severity_values, do: @severity_values

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [:body, :category, :source_id, :fingerprint, :error_count, :severity, :status, :done_note, :metadata])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 16_000)
    |> validate_length(:category, max: 255)
    |> validate_length(:source_id, max: 255)
    |> validate_length(:done_note, max: 2_000)
  end
end
