defmodule Maya.Repo.Migrations.CreateTrainerAndItemPlaces do
  use Ecto.Migration

  # Trainers and items per place, each row tagged with its own Spoiler horizon
  # (trainers-items-readiness part A). `location` is the listed location a row is told under.
  def change do
    create table(:items) do
      add :name, :string, null: false
    end

    create unique_index(:items, [:name])

    create table(:trainer_places) do
      add :map, :string, null: false
      add :location, :string, null: false
      add :badges_required, :integer, null: false
      add :trainer_label, :string, null: false
      add :name, :string, null: false
    end

    create index(:trainer_places, [:location])

    create table(:item_places) do
      add :item, :string, null: false
      add :map, :string, null: false
      add :location, :string, null: false
      add :how, :string, null: false
      add :badges_required, :integer, null: false
    end

    create index(:item_places, [:item])
  end
end
