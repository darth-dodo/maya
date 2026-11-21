defmodule Maya.Repo.Migrations.CreateTypeReasons do
  use Ecto.Migration

  # One hand-written reason line per notable type pair, checked against the chart (type-matchup).
  def change do
    create table(:type_reasons) do
      add :attacker, :string, null: false
      add :defender, :string, null: false
      add :multiplier, :float, null: false
      add :reason, :string, null: false
    end

    create unique_index(:type_reasons, [:attacker, :defender])
  end
end
