defmodule Reverb.Repo.Migrations.CreateReverbTasks do
  use Ecto.Migration

  def change do
    create table(:reverb_tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :category, :string
      add :source_id, :string
      add :fingerprint, :string
      add :error_count, :integer, default: 1, null: false
      add :severity, :string, default: "medium", null: false
      add :status, :string, default: "new", null: false
      add :done_note, :text
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:reverb_tasks, [:fingerprint])
    create index(:reverb_tasks, [:status])
    create index(:reverb_tasks, [:inserted_at])
    create index(:reverb_tasks, [:severity])
  end
end
