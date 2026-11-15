defmodule Maya.Repo.Migrations.CreateLearnsets do
  use Ecto.Migration

  # Emerald moves per species (PokeAPI); `method` is level-up today, machine and tutor later.
  # The id keeps the file's order, so moves learned at the same level stay in game order.
  def change do
    create table(:learnsets) do
      add :species, :string, null: false
      add :move, :string, null: false
      add :method, :string, null: false
      add :level, :integer, null: false
    end

    create index(:learnsets, [:species])
  end
end
