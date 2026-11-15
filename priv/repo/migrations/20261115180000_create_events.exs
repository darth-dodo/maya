defmodule Maya.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  # ADR-006: an Event and the Progress it changes are written together; `previous` is the
  # Progress before it (badges, team, location), so undo can restore it.
  def change do
    create table(:events) do
      add :guest_id, :string, null: false
      add :kind, :string, null: false
      add :details, :jsonb, null: false, default: "{}"
      add :previous, :jsonb, null: false
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:events, [:guest_id])
  end
end
