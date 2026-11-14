defmodule Maya.Repo.Migrations.CreateTurns do
  use Ecto.Migration

  # One row per Question and Answer, text only (ADR-006), with per-stage milliseconds.
  def change do
    create table(:turns) do
      add :question, :text, null: false
      add :answer, :text, null: false
      add :cut, :boolean, null: false, default: false
      add :mic_release_ms, :integer
      add :stt_ms, :integer
      add :tts_first_byte_ms, :integer
      add :playback_start_ms, :integer

      timestamps(type: :utc_datetime_usec)
    end
  end
end
