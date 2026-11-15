defmodule Maya.Repo.Migrations.AddConfirmMsAndTypedToTurns do
  use Ecto.Migration

  # The countdown stage and typed Questions (#95). Additive; older turns get null and false.
  def change do
    alter table(:turns) do
      add :confirm_ms, :integer
      add :typed, :boolean, default: false, null: false
    end
  end
end
