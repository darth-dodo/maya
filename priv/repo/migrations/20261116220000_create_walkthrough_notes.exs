defmodule Maya.Repo.Migrations.CreateWalkthroughNotes do
  use Ecto.Migration

  # One hand-written note per listed location, tagged with its Spoiler horizon (guide-and-humor).
  def change do
    create table(:walkthrough_notes) do
      add :location, :string, null: false
      add :badges_required, :integer, null: false
      add :text, :text, null: false
    end

    create index(:walkthrough_notes, [:location])
  end
end
