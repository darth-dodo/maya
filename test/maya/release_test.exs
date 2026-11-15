defmodule Maya.ReleaseTest do
  # Not async: the migrator locks schema_migrations.
  use Maya.DataCase, async: false

  alias Maya.GameData

  @tables ~w(species type_matchups encounters trainers trainer_pokemon locations progress)
  @guest_migration 20_261_115_120_000

  test "the pre-deploy migrate seeds game data only, and a second deploy changes nothing" do
    Maya.Release.migrate()

    assert %{name: "Roxanne"} = GameData.trainer("Roxanne1")
    assert Repo.aggregate("progress", :count) == 0

    GameData.progress("guest-a")
    counts = row_counts()
    Repo.query!("UPDATE progress SET badges = '{1}'")

    Maya.Release.migrate()

    assert row_counts() == counts
    assert %{badges: [1]} = GameData.progress("guest-a")
  end

  test "the guest migration gives existing turns and Progress to the legacy guest, losing none" do
    # No migration lock: the lock would hold the one sandbox connection the migration Task needs.
    Ecto.Migrator.run(Repo, :down, to: @guest_migration, log: false, migration_lock: false)

    Repo.query!("""
    INSERT INTO turns (question, answer, inserted_at, updated_at)
    VALUES ('Where is Ralts', 'Route 102', now(), now())
    """)

    # The old seed's hand-written id 1.
    Repo.query!("""
    INSERT INTO progress (id, badges, team, location, humor, inserted_at, updated_at)
    VALUES (1, '{1}', '[]', 'Rustboro City', 75, now(), now())
    """)

    Ecto.Migrator.run(Repo, :up, all: true, log: false, migration_lock: false)

    assert [%{question: "Where is Ralts"}] = Maya.Voice.Turn.recent("legacy")
    assert %{badges: [1], location: "Rustboro City"} = GameData.progress("legacy")
    # The id sequence moved past 1, so a new guest's seed does not collide.
    assert %{badges: []} = GameData.progress("guest-a")
  end

  defp row_counts, do: Map.new(@tables, &{&1, Repo.aggregate(&1, :count)})
end
