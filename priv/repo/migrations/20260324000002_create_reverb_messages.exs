defmodule Reverb.Repo.Migrations.CreateReverbMessages do
  use Ecto.Migration

  def change do
    create table(:reverb_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :kind, :string, null: false
      add :message, :text, null: false
      add :source, :string
      add :stacktrace, :text
      add :metadata, :map, default: %{}
      add :severity, :string
      add :node, :string
      add :fingerprint, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:reverb_messages, [:fingerprint])
    create index(:reverb_messages, [:inserted_at])
  end
end
