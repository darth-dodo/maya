defmodule Maya.GameData.NotesTest do
  use ExUnit.Case, async: true

  alias Maya.GameData.Notes

  @read &(&1 |> File.read!() |> Jason.decode!())
  @locations @read.("priv/data/locations.json")
  @notes @read.("priv/data/walkthrough_notes.json")
  @forbidden @read.("test/fixtures/spoiler_probes.json")["forbidden"]

  test "21 locations, Littleroot Town to Mauville City, with their badges" do
    by_badges =
      @locations |> Enum.group_by(& &1["badges_required"], & &1["name"]) |> Map.new()

    assert length(@locations) == 21
    assert length(by_badges[0]) == 9 and List.last(by_badges[0]) == "Rustboro City"

    assert by_badges[1] == [
             "Route 116",
             "Rusturf Tunnel",
             "Route 105",
             "Route 106",
             "Dewford Town",
             "Granite Cave",
             "Route 109",
             "Slateport City"
           ]

    assert by_badges[2] == ["Route 107", "Route 108", "Route 110", "Mauville City"]

    assert %{"map" => "MAP_GRANITE_CAVE_1F"} =
             Enum.find(@locations, &(&1["name"] == "Granite Cave"))
  end

  test "one note per location, tagged with its badges" do
    assert Enum.map(@notes, &{&1["location"], &1["badges_required"]}) ==
             Enum.map(@locations, &{&1["name"], &1["badges_required"]})
  end

  test "the committed notes pass the checker, with the spoiler probe list too" do
    assert Notes.problems(@notes, @locations, @forbidden) == []
  end

  test "notes use inclusive language and spell Pokémon with an accent" do
    for %{"text" => text} <- @notes do
      refute text =~ ~r/\b(beat|beats|beaten|beating|defeat\w*)\b/i
      refute text =~ ~r/Pokemon/
    end
  end

  test "a note naming a place past its horizon is reported" do
    notes = [
      %{
        "location" => "Rustboro City",
        "badges_required" => 0,
        "text" => "Then head to Route 116."
      },
      %{
        "location" => "Slateport City",
        "badges_required" => 1,
        "text" => "Head north to Mauville City."
      }
    ]

    assert Notes.problems(notes, @locations) == [
             {"Rustboro City", {:names, "Route 116"}},
             {"Slateport City", {:names, "Mauville City"}}
           ]
  end

  test "later gyms and probe names are reported, names inside the horizon are not" do
    assert Notes.leaks("Wattson waits in Mauville.", 1, @locations, @forbidden) == [
             "Wattson",
             "Mauville"
           ]

    assert Notes.leaks("Brawly is in Dewford, then Slateport.", 1, @locations, @forbidden) == []
    assert Notes.leaks("Not New Mauville yet.", 2, @locations, @forbidden) == ["New Mauville"]
  end

  test "an unlisted location or a lower badge tag fails closed" do
    notes = [
      %{"location" => "Verdanturf Town", "badges_required" => 3, "text" => "Quiet."},
      %{"location" => "Dewford Town", "badges_required" => 0, "text" => "Brawly."}
    ]

    assert Notes.problems(notes, @locations) == [
             {"Verdanturf Town", :unlisted},
             {"Dewford Town", :badge_below}
           ]
  end
end
