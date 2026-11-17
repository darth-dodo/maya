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
    "ralts" => %{name: "ralts", evolutions: [%{"into" => "kirlia", "min_level" => 20}]},
    "taillow" => %{name: "taillow", evolutions: []},
    "wingull" => %{name: "wingull", evolutions: []},
    "shroomish" => %{name: "shroomish", evolutions: []}
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

  defp m(species, level), do: %{"species" => species, "level" => level}
  defp holding(team, box \\ []), do: %{@progress | team: team, box: box}

  describe "deposited" do
    test "Deposit: one Team member to the end of the PC box" do
      p = holding([m("mudkip", 16), m("wingull", 9)], [m("lotad", 6)])

      assert {:ok, new, "Wingull sent to the PC."} =
               change(p, "deposited", %{"species" => "Wingull"})

      assert new.team == [m("mudkip", 16)]
      assert new.box == [m("lotad", 6), m("wingull", 9)]
    end

    test "The last Team member is refused" do
      assert change("deposited", %{"species" => "mudkip"}) ==
               {:refused, "Your Team needs at least one Pokémon."}
    end

    test "Not on the Team is refused" do
      assert change(holding([m("mudkip", 16), m("wingull", 9)], [m("lotad", 6)]), "deposited", %{
               "species" => "lotad"
             }) == {:refused, "I can only deposit a Pokémon on your Team."}
    end
  end

  describe "withdrawn" do
    test "Withdraw: one PC box member to the end of the Team, same level" do
      p = holding([m("mudkip", 16), m("wingull", 9)], [m("lotad", 6)])

      assert {:ok, new, "Lotad level 6 joined the Team."} =
               change(p, "withdrawn", %{"species" => "Lotad"})

      assert new.team == [m("mudkip", 16), m("wingull", 9), m("lotad", 6)]
      assert new.box == []
    end

    test "Withdraw with a full Team names the lowest level member, ties to the last" do
      team = [
        m("mudkip", 16),
        m("taillow", 12),
        m("wingull", 9),
        m("ralts", 7),
        m("zigzagoon", 7),
        m("poochyena", 10)
      ]

      assert change(holding(team, [m("lotad", 6)]), "withdrawn", %{"species" => "lotad"}) ==
               {:refused, "The Team is full at 6. Deposit one first, maybe Zigzagoon."}
    end

    test "Not in the PC box is refused" do
      assert change("withdrawn", %{"species" => "lotad"}) ==
               {:refused, "I can only withdraw a Pokémon in the PC."}
    end
  end

  describe "set_lead" do
    test "New lead: to the front, the rest keep their order" do
      p = holding([m("mudkip", 16), m("taillow", 12), m("wingull", 9)])

      assert {:ok, new, "Wingull leads the Team now."} =
               change(p, "set_lead", %{"species" => "Wingull"})

      assert new.team == [m("wingull", 9), m("mudkip", 16), m("taillow", 12)]
    end

    test "In the PC box: withdraw it first" do
      assert change(holding([m("mudkip", 16)], [m("lotad", 6)]), "set_lead", %{
               "species" => "lotad"
             }) ==
               {:refused, "Lotad is in the PC, withdraw it first."}
    end

    test "on neither is refused" do
      assert {:refused, _} = change("set_lead", %{"species" => "lotad"})
    end

    test "Already the lead changes nothing" do
      assert {:ok, @progress, "Mudkip already leads the Team."} =
               change("set_lead", %{"species" => "Mudkip"})
    end
  end

  describe "set_level" do
    test "A lower level" do
      p = holding([m("mudkip", 16), m("poochyena", 12)])

      assert {:ok, new, "Poochyena is level 9 now."} =
               change(p, "set_level", %{"species" => "poochyena", "level" => 9})

      assert new.team == [m("mudkip", 16), m("poochyena", 9)]
    end

    test "In the PC box" do
      p = holding([m("mudkip", 16)], [m("lotad", 6)])

      assert {:ok, %{box: [%{"species" => "lotad", "level" => 8}]}, _} =
               change(p, "set_level", %{"species" => "lotad", "level" => 8})
    end

    test "Neither is refused" do
      assert change("set_level", %{"species" => "lotad", "level" => 8}) ==
               {:refused, "I can only set a level for a Pokémon on your Team or in the PC."}
    end

    test "Level out of range" do
      for level <- [0, 101, "thirteen"] do
        assert change("set_level", %{"species" => "mudkip", "level" => level}) ==
                 {:refused, "Levels go from 1 to 100."}
      end
    end

    test "the same level changes nothing" do
      assert {:ok, @progress, "Mudkip is already level 5."} =
               change("set_level", %{"species" => "mudkip", "level" => 5})
    end
  end

  describe "set_team" do
    defp named(list), do: %{"team" => Enum.map(list, fn {s, l} -> m(s, l) end)}

    test "My Team is: named from Team then PC box, the rest to the PC, never deleted" do
      p = holding([m("mudkip", 14), m("wingull", 9), m("ralts", 7)], [m("taillow", 11)])

      assert {:ok, new, "Team set: Mudkip level 16, Taillow level 12. 2 sent to the PC."} =
               change(p, "set_team", named([{"Mudkip", 16}, {"Taillow", 12}]))

      assert new.team == [m("mudkip", 16), m("taillow", 12)]
      assert new.box == [m("wingull", 9), m("ralts", 7)]
    end

    test "a level left out keeps that member's level" do
      p = holding([m("mudkip", 14), m("wingull", 9)])

      assert {:ok, %{team: [%{"species" => "wingull", "level" => 9}]}, _} =
               change(p, "set_team", %{"team" => [%{"species" => "wingull"}]})
    end

    test "a new species joins with its level" do
      assert {:ok, %{team: [_, %{"species" => "ralts", "level" => 4}]}, _} =
               change("set_team", named([{"mudkip", 5}, {"ralts", 4}]))
    end

    test "A new species with no level is refused" do
      assert change("set_team", %{"team" => [%{"species" => "Shroomish"}]}) ==
               {:refused, "What level is Shroomish?"}
    end

    test "Too many or none is refused" do
      for team <- [[], List.duplicate(m("mudkip", 5), 7), nil] do
        assert change("set_team", %{"team" => team}) ==
                 {:refused, "A Team holds 1 to 6 Pokémon."}
      end
    end

    test "Unknown species is refused" do
      assert change("set_team", named([{"Agumon", 5}])) ==
               {:refused, "That Pokémon is not in my data."}
    end

    test "a bad level is refused" do
      assert change("set_team", named([{"mudkip", 0}])) == {:refused, "Levels go from 1 to 100."}
    end

    test "The same Team again changes nothing" do
      assert {:ok, @progress, "That is already your Team."} =
               change("set_team", named([{"mudkip", 5}]))
    end
  end

  describe "slot" do
    test "The second Poochyena" do
      p = holding([m("poochyena", 9), m("mudkip", 16), m("poochyena", 12)])

      assert {:ok, new, _} =
               change(p, "set_level", %{"species" => "poochyena", "level" => 13, "slot" => 3})

      assert new.team == [m("poochyena", 9), m("mudkip", 16), m("poochyena", 13)]
    end

    test "A stale slot is refused on every kind that takes one" do
      p = holding([m("mudkip", 16), m("taillow", 12), m("wingull", 9)], [m("lotad", 6)])

      for {kind, details} <- [
            {"deposited", %{"species" => "wingull", "slot" => 2}},
            {"set_lead", %{"species" => "wingull", "slot" => 2}},
            {"set_level", %{"species" => "wingull", "level" => 3, "slot" => 2}},
            {"released", %{"species" => "wingull", "slot" => 9}},
            {"withdrawn", %{"species" => "lotad", "slot" => 2}}
          ] do
        assert change(p, kind, details) == {:refused, "That Pokémon moved, so nothing changed."}
      end
    end

    test "a slot picks that member for deposited, released and withdrawn" do
      p = holding([m("wingull", 5), m("wingull", 9)], [m("lotad", 6), m("lotad", 8)])

      assert {:ok, %{team: [m1], box: [_, _, m2]}, _} =
               change(p, "deposited", %{"species" => "wingull", "slot" => 2})

      assert {m1, m2} == {m("wingull", 5), m("wingull", 9)}

      assert {:ok, %{team: [%{"level" => 9}]}, _} =
               change(p, "released", %{"species" => "wingull", "slot" => 1})

      assert {:ok, %{team: [_, _, %{"level" => 8}], box: [%{"level" => 6}]}, _} =
               change(p, "withdrawn", %{"species" => "lotad", "slot" => 2})
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
