defmodule Reverb.Repo.Migrations.ExpandReverbTasksAndCreateRuns do
  use Ecto.Migration

  def change do
    alter table(:reverb_tasks) do
      add :source_kind, :string, default: "signal", null: false
      add :subject, :string
      add :attempt_count, :integer, default: 0, null: false
      add :priority, :integer, default: 100, null: false
      add :state, :string, default: "pending", null: false
      add :validation_status, :string, default: "pending", null: false
      add :remote_status, :string, default: "local_only", null: false
      add :assigned_agent, :string
      add :lease_expires_at, :utc_datetime
      add :branch_name, :string
      add :workspace_path, :text
      add :current_run_id, :binary_id
      add :steering_notes, :text
      add :last_error, :text
    end

    create index(:reverb_tasks, [:state])
    create index(:reverb_tasks, [:priority])
    create index(:reverb_tasks, [:lease_expires_at])
    create index(:reverb_tasks, [:subject])

    create table(:reverb_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :task_id, references(:reverb_tasks, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, default: "queued", null: false
      add :assigned_agent, :string
      add :branch_name, :string
      add :workspace_path, :text
      add :agent_output, :text
      add :validation_output, :text
      add :last_error, :text
      add :pr_url, :text
      add :remote_ref, :text
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:reverb_runs, [:task_id])
    create index(:reverb_runs, [:status])
    create index(:reverb_runs, [:inserted_at])
  end
end
