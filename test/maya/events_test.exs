defmodule Maya.EventsTest do
  use ExUnit.Case, async: true

  alias Maya.{Events, Horizon}

  @progress %{
    badges: [],
    team: [%{"species" => "mudkip", "level" => 5}],
    box: [],
    location: "Littleroot Town",
    humor: 75
  }

  @species %{
    "mudkip" => %{name: "mudkip", evolutions: [%{"into" => "marshtomp", "min_level" => 16}]},
    "marshtomp" => %{name: "marshtomp", evolutions: []},
    "ralts" => %{name: "ralts", evolutions: [%{"into" => "kirlia", "min_level" => 20}]}
  }

  @locations [
    %{name: "Rustboro City", map: "MAP_RUSTBORO_CITY", badges_required: 0},
    %{name: "Dewford Town", map: "MAP_DEWFORD_TOWN", badges_required: 1}
  ]

  defp data, do: %{species: &Map.get(@species, &1), locations: @locations}

  defp change(progress \\ @progress, kind, details),
    do: Events.change(progress, kind, details, data())

  describe "badge_earned" do
    test "Roxanne's badge by leader moves the Next gym to Brawly" do
      assert {:ok, progress, "Stone Badge logged. Mudkip would approve."} =
               change("badge_earned", %{"leader" => "Roxanne's"})

      assert progress.badges == [1]
      assert Horizon.next_gym(progress).leader == "Brawly"
    end

    test "by badge number" do
      assert {:ok, %{badges: [1]}, _line} = change("badge_earned", %{"badge" => 1})
    end

    test "a later, unknown or out of range badge gets one refusal naming only the Next gym" do
      for details <- [
            %{"leader" => "Wattson"},
            %{"leader" => "Giovanni"},
            %{"badge" => 3},
            %{"badge" => 9},
            %{}
          ] do
        assert change("badge_earned", details) ==
                 {:refused, "I can only log Roxanne's badge next."}
      end
    end

    test "a badge already earned is refused" do
      assert change(%{@progress | badges: [1]}, "badge_earned", %{"leader" => "Roxanne"}) ==
               {:refused, "You already have the Stone Badge."}
    end

    test "with all 8 badges there is nothing left to log" do
      assert {:refused, "Every badge is already logged."} =
               change(%{@progress | badges: Enum.to_list(1..8)}, "badge_earned", %{"badge" => 8})
    end
  end

  describe "caught" do
    test "joins the Team" do
      assert {:ok, progress, "Ralts level 4 logged on the Team."} =
               change("caught", %{"species" => "Ralts", "level" => 4})

      assert List.last(progress.team) == %{"species" => "ralts", "level" => 4}
    end

    test "an unknown species is refused" do
      assert change("caught", %{"species" => "Agumon", "level" => 4}) ==
               {:refused, "That Pokémon is not in my data."}
    end

    test "with a full Team it goes to the PC box, never refused (#116)" do
      team = List.duplicate(%{"species" => "mudkip", "level" => 5}, 6)

      assert {:ok, progress, "Ralts level 4 sent to the PC, the Team is full at 6."} =
               change(%{@progress | team: team}, "caught", %{"species" => "ralts", "level" => 4})

      assert progress.team == team
      assert progress.box == [%{"species" => "ralts", "level" => 4}]
    end
  end

  describe "released" do
    test "removes one matching Pokémon from the Team, so a duplicate can be fixed (#116)" do
      team = [%{"species" => "mudkip", "level" => 5}, %{"species" => "ralts", "level" => 4}]
      dup = %{@progress | team: team ++ [%{"species" => "ralts", "level" => 4}]}

      assert {:ok, progress, "Ralts released from the Team."} =
               change(dup, "released", %{"species" => "Ralts"})

      assert progress.team == team
    end

    test "falls back to the PC box" do
      boxed = %{@progress | box: [%{"species" => "ralts", "level" => 4}]}

      assert {:ok, %{box: [], team: [_]}, "Ralts released from the PC."} =
               change(boxed, "released", %{"species" => "ralts"})
    end

    test "a Pokémon in neither is refused" do
      assert change("released", %{"species" => "ralts"}) ==
               {:refused, "I can only release a Pokémon on your Team or in the PC."}
    end
  end

  describe "repeat?" do
    @poochyena %{"species" => "Poochyena", "level" => 9}
    @recent [%{details: %{"species" => "poochyena ", "level" => 9}}]

    defp holding_poochyena,
      do: %{@progress | team: @progress.team ++ [%{"species" => "poochyena", "level" => 9}]}

    test "the same catch logged again in the window is a repeat (#116)" do
      assert Events.repeat?(holding_poochyena(), @poochyena, @recent)
    end

    test "a catch at another level, or none in the window, is not a repeat" do
      refute Events.repeat?(holding_poochyena(), @poochyena, [])
      refute Events.repeat?(holding_poochyena(), %{@poochyena | "level" => 10}, @recent)
    end

    test "a catch after that Pokémon was released is not a repeat" do
      refute Events.repeat?(@progress, @poochyena, @recent)
    end
  end

  describe "level_up" do
    test "sets the level of that Team member" do
      assert {:ok, progress, "Mudkip level 13 logged."} =
               change("level_up", %{"species" => "mudkip", "level" => 13})

      assert progress.team == [%{"species" => "mudkip", "level" => 13}]
    end

    test "levels outside 1 to 100 or not whole numbers are refused" do
      for level <- [0, 101, "thirteen", 12.5, nil] do
        assert change("level_up", %{"species" => "mudkip", "level" => level}) ==
                 {:refused, "Levels go from 1 to 100."}
      end
    end

    test "a species not on the Team is refused" do
      assert change("level_up", %{"species" => "ralts", "level" => 7}) ==
               {:refused, "I can only log that for a Pokémon on your Team."}
    end
  end

  describe "evolved" do
    test "replaces the Team member and keeps its level" do
      progress = %{@progress | team: [%{"species" => "mudkip", "level" => 16}]}

      assert {:ok, new, "Marshtomp logged, evolved from Mudkip."} =
               change(progress, "evolved", %{"from" => "Mudkip", "to" => "Marshtomp"})

      assert new.team == [%{"species" => "marshtomp", "level" => 16}]
    end

    test "an evolution the data does not list is refused" do
      assert change("evolved", %{"from" => "mudkip", "to" => "ralts"}) ==
               {:refused, "Not sure that is how it evolves."}
    end

    test "a species not on the Team is refused" do
      assert change("evolved", %{"from" => "ralts", "to" => "kirlia"}) ==
               {:refused, "I can only log that for a Pokémon on your Team."}
    end
  end

  describe "moved" do
    test "to a location inside the horizon" do
      assert {:ok, %{location: "Dewford Town"}, "Location logged: Dewford Town."} =
               change(%{@progress | badges: [1]}, "moved", %{"location" => "dewford town"})
    end

    test "past the horizon or unlisted is refused without naming a place" do
      for location <- ["Dewford Town", "Mauville City"] do
        assert change("moved", %{"location" => location}) ==
                 {:refused, "I can only log places up to the Next gym."}
      end
    end
  end

  test "an unknown kind or missing details are refused" do
    assert {:refused, _} = change("dance", %{})
    assert {:refused, _} = change("caught", %{"level" => 4})
  end

  test "no line uses beat or defeat" do
    lines =
      for {kind, details} <- [
            {"badge_earned", %{"leader" => "Roxanne"}},
            {"badge_earned", %{"leader" => "Wattson"}},
            {"caught", %{"species" => "agumon", "level" => 4}},
            {"moved", %{"location" => "Mauville City"}}
          ] do
        change(kind, details) |> Tuple.to_list() |> List.last()
      end

    for line <- lines, do: refute(line =~ ~r/\b(beat|defeat)/i)
  end
end
