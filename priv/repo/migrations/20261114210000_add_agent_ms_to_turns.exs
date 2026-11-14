defmodule Maya.Repo.Migrations.AddAgentMsToTurns do
  use Ecto.Migration

  # The agent stage (Block 3); older turns read as missing in mix maya.latency.
  def change do
    alter table(:turns) do
      add :agent_ms, :integer
    end
  end
end
