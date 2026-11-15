defmodule Maya.Repo.Migrations.AddSttSourceToTurns do
  use Ecto.Migration

  # Which STT gave the final transcript, "realtime" or "batch" (ADR-009); null for older turns.
  def change do
    alter table(:turns) do
      add :stt_source, :string
    end
  end
end
