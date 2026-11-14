defmodule Maya.ReleaseTest do
  # Not async: the migrator locks schema_migrations.
  use Maya.DataCase, async: false

  alias Maya.GameData

  @tables ~w(species type_matchups encounters trainers trainer_pokemon locations progress)

  test "the pre-deploy migrate seeds game data and Progress, and a second deploy changes nothing" do
    assert GameData.progress() == nil

    Maya.Release.migrate()

    assert %{name: "Roxanne"} = GameData.trainer("Roxanne1")
    assert %{badges: []} = GameData.progress()

    counts = row_counts()
    Repo.query!("UPDATE progress SET badges = '{1}'")

    Maya.Release.migrate()

    assert row_counts() == counts
    assert %{badges: [1]} = GameData.progress()
  end

  defp row_counts, do: Map.new(@tables, &{&1, Repo.aggregate(&1, :count)})
end
