defmodule Maya.Repo.Migrations.CreateGameData do
  use Ecto.Migration

  def change do
    create table(:species, primary_key: false) do
      add :name, :string, primary_key: true
      add :types, {:array, :string}, null: false
      add :evolutions, :jsonb, null: false, default: "[]"
    end

    create table(:type_matchups, primary_key: false) do
      add :attacker, :string, primary_key: true
      add :defender, :string, primary_key: true
      add :multiplier, :float, null: false
    end

    create table(:encounters) do
      add :map, :string, null: false
      add :method, :string, null: false
      add :species, :string, null: false
      add :rate, :integer, null: false
      add :min_level, :integer, null: false
      add :max_level, :integer, null: false
    end

    create index(:encounters, [:species])
    create unique_index(:encounters, [:map, :method, :species])

    create table(:trainers, primary_key: false) do
      add :label, :string, primary_key: true
      add :name, :string, null: false
      add :gym_badge, :integer
    end

    create table(:trainer_pokemon) do
      add :trainer_label,
          references(:trainers, column: :label, type: :string, on_delete: :delete_all),
          null: false

      add :slot, :integer, null: false
      add :species, :string, null: false
      add :level, :integer, null: false
      add :moves, {:array, :string}, null: false, default: []
    end

    create unique_index(:trainer_pokemon, [:trainer_label, :slot])

    create table(:locations, primary_key: false) do
      add :name, :string, primary_key: true
      add :map, :string, null: false
      add :badges_required, :integer, null: false
    end

    # One row (id 1): seeded once from priv/progress.json, then changed only by Events (ADR-006).
    create table(:progress) do
      add :badges, {:array, :integer}, null: false, default: []
      add :team, :jsonb, null: false, default: "[]"
      add :location, :string, null: false
      add :humor, :integer, null: false
      timestamps(type: :utc_datetime)
    end
  end
end
