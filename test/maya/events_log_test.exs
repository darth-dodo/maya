defmodule Maya.EventsLogTest do
  use Maya.DataCase, async: true

  alias Maya.{Events, GameData, Horizon}

  setup do
    :ok = GameData.import!()
    %{progress: GameData.progress("events-guest")}
  end

  defp events(guest_id),
    do: Repo.all(from e in "events", where: e.guest_id == ^guest_id, select: e.kind)

  test "Roxanne's badge is one Event and the Guest's Progress, in one write", %{progress: p} do
    assert {:ok, "Stone Badge logged. Mudkip would approve.", new} =
             Events.log(p, "badge_earned", %{"leader" => "Roxanne"})

    assert new.badges == [1]
    assert GameData.progress("events-guest").badges == [1]
    assert Horizon.next_gym(GameData.progress("events-guest")).leader == "Brawly"
    assert events("events-guest") == ["badge_earned"]
  end

  test "another Guest's Progress is untouched", %{progress: p} do
    GameData.progress("other-guest")
    {:ok, _, _} = Events.log(p, "badge_earned", %{"leader" => "Roxanne"})

    assert GameData.progress("other-guest").badges == []
    assert events("other-guest") == []
  end

  test "a refusal writes nothing", %{progress: p} do
    assert {:refused, "I can only log Roxanne's badge next."} =
             Events.log(p, "badge_earned", %{"leader" => "Wattson"})

    assert GameData.progress("events-guest").badges == []
    assert events("events-guest") == []
  end

  test "species and locations come from the imported data", %{progress: p} do
    assert {:ok, "Ralts level 4 logged on the Team.", _} =
             Events.log(p, "caught", %{"species" => "Ralts", "level" => 4})

    assert {:refused, "That Pokémon is not in my data."} =
             Events.log(p, "caught", %{"species" => "Agumon", "level" => 4})

    assert {:ok, _, _} = Events.log(p, "level_up", %{"species" => "Mudkip", "level" => 16})

    assert {:ok, "Marshtomp logged, evolved from Mudkip.", _} =
             Events.log(p, "evolved", %{"from" => "Mudkip", "to" => "Marshtomp"})

    assert [%{"species" => "marshtomp", "level" => 16}, %{"species" => "ralts"}] =
             GameData.progress("events-guest").team
  end

  test "undo restores the Progress from before the last Event", %{progress: p} do
    {:ok, _, _} = Events.log(p, "badge_earned", %{"leader" => "Roxanne"})
    {:ok, _, _} = Events.log(p, "moved", %{"location" => "Dewford Town"})

    assert {:ok, "Undone, that Event is off the record.", after_one} = Events.log(p, "undo", %{})
    assert after_one.location == "Littleroot Town"
    assert after_one.badges == [1]

    assert {:ok, _, _} = Events.log(p, "undo", %{})
    assert %{badges: [], location: "Littleroot Town"} = GameData.progress("events-guest")
    assert Horizon.next_gym(GameData.progress("events-guest")).leader == "Roxanne"
    assert events("events-guest") == []

    assert Events.log(p, "undo", %{}) == {:refused, "There is nothing to undo."}
  end

  describe "#116" do
    @poochyena %{"species" => "Poochyena", "level" => 9}

    test "the same catch logged twice in a row is one Event and one Team slot", %{progress: p} do
      assert {:ok, "Poochyena level 9 logged on the Team.", _} =
               Events.log(p, "caught", @poochyena)

      assert {:ok, "Poochyena level 9 is already logged.", again} =
               Events.log(p, "caught", %{"species" => "poochyena", "level" => 9})

      assert length(again.team) == 2
      assert length(GameData.progress("events-guest").team) == 2
      assert events("events-guest") == ["caught"]
    end

    test "a catch with a full Team goes to the PC box, and undo takes it out", %{progress: p} do
      for name <- ~w(Ralts Wingull Zigzagoon Wurmple Poochyena),
          do: {:ok, _, _} = Events.log(p, "caught", %{"species" => name, "level" => 5})

      assert {:ok, "Lotad level 6 sent to the PC, the Team is full at 6.", _} =
               Events.log(p, "caught", %{"species" => "Lotad", "level" => 6})

      progress = GameData.progress("events-guest")
      assert length(progress.team) == 6
      assert progress.box == [%{"species" => "lotad", "level" => 6}]

      {:ok, _, _} = Events.log(p, "undo", %{})
      assert GameData.progress("events-guest").box == []
    end

    test "a catch repeated after another one in the window is still one slot", %{progress: p} do
      {:ok, _, _} = Events.log(p, "caught", @poochyena)
      {:ok, _, _} = Events.log(p, "caught", %{"species" => "Wingull", "level" => 9})
      {:ok, _, _} = Events.log(p, "caught", @poochyena)

      assert ["mudkip", "poochyena", "wingull"] =
               Enum.map(GameData.progress("events-guest").team, & &1["species"])
    end

    test "released removes one existing duplicate from the Team", %{progress: p} do
      pooch = %{"species" => "poochyena", "level" => 9}

      GameData.put_progress!(%{
        p
        | team: p.team ++ [pooch, %{"species" => "wingull", "level" => 9}, pooch]
      })

      assert {:ok, "Poochyena released from the Team.", _} =
               Events.log(p, "released", %{"species" => "Poochyena"})

      assert ["mudkip", "wingull", "poochyena"] =
               Enum.map(GameData.progress("events-guest").team, & &1["species"])
    end
  end

  describe "team-voice" do
    defp m(species, level), do: %{"species" => species, "level" => level}

    defp team!(p, team, box \\ []), do: GameData.put_progress!(%{p | team: team, box: box})

    test "Undo a whole Team", %{progress: p} do
      team!(p, [m("mudkip", 14), m("wingull", 9), m("ralts", 7)], [m("taillow", 11)])

      assert {:ok, "Team set: Mudkip level 16, Taillow level 12. 2 sent to the PC.", _} =
               Events.log(p, "set_team", %{"team" => [m("Mudkip", 16), m("Taillow", 12)]})

      assert {:ok, _, _} = Events.log(p, "undo", %{})
      progress = GameData.progress("events-guest")
      assert progress.team == [m("mudkip", 14), m("wingull", 9), m("ralts", 7)]
      assert progress.box == [m("taillow", 11)]
    end

    test "each new kind is one Event and undoable", %{progress: p} do
      team!(p, [m("mudkip", 16), m("wingull", 9)], [m("lotad", 6)])

      for {kind, details} <- [
            {"deposited", %{"species" => "Wingull"}},
            {"withdrawn", %{"species" => "Lotad"}},
            {"set_lead", %{"species" => "Lotad"}},
            {"set_level", %{"species" => "Lotad", "level" => 8}}
          ] do
        before = Map.take(GameData.progress("events-guest"), [:team, :box])
        assert {:ok, _, _} = Events.log(p, kind, details)
        assert events("events-guest") == [kind]
        assert {:ok, _, _} = Events.log(p, "undo", %{})
        assert Map.take(GameData.progress("events-guest"), [:team, :box]) == before
        {:ok, _, _} = Events.log(p, kind, details)
        Repo.delete_all(from e in "events", where: e.guest_id == "events-guest")
      end
    end

    test "Already the lead writes no Event, and undo undoes the Event before it", %{progress: p} do
      {:ok, _, _} = Events.log(p, "caught", m("Ralts", 4))

      assert {:ok, "Mudkip already leads the Team.", _} =
               Events.log(p, "set_lead", %{"species" => "Mudkip"})

      assert events("events-guest") == ["caught"]
      {:ok, _, _} = Events.log(p, "undo", %{})
      assert GameData.progress("events-guest").team == [m("mudkip", 5)]
    end

    test "The same Team again is one Event", %{progress: p} do
      details = %{"team" => [m("Mudkip", 16), m("Taillow", 12)]}
      {:ok, _, _} = Events.log(p, "set_team", details)
      assert {:ok, "That is already your Team.", _} = Events.log(p, "set_team", details)
      assert events("events-guest") == ["set_team"]
    end

    test "The same deposit twice is one Event", %{progress: p} do
      team!(p, [m("mudkip", 16), m("wingull", 9), m("wingull", 9)])
      {:ok, "Wingull sent to the PC.", _} = Events.log(p, "deposited", %{"species" => "Wingull"})

      assert {:ok, "Wingull is already in the PC.", _} =
               Events.log(p, "deposited", %{"species" => "wingull"})

      progress = GameData.progress("events-guest")
      assert progress.team == [m("mudkip", 16), m("wingull", 9)]
      assert progress.box == [m("wingull", 9)]
      assert events("events-guest") == ["deposited"]
    end

    test "the same withdraw twice is one Event", %{progress: p} do
      team!(p, [m("mudkip", 16)], [m("lotad", 6), m("lotad", 6)])
      {:ok, _, _} = Events.log(p, "withdrawn", %{"species" => "Lotad"})

      assert {:ok, "Lotad is already on the Team.", _} =
               Events.log(p, "withdrawn", %{"species" => "Lotad"})

      assert length(GameData.progress("events-guest").box) == 1
    end

    test "A deposit after an undo is logged", %{progress: p} do
      team!(p, [m("mudkip", 16), m("wingull", 9)])
      {:ok, _, _} = Events.log(p, "deposited", %{"species" => "Wingull"})
      {:ok, _, _} = Events.log(p, "undo", %{})

      assert {:ok, "Wingull sent to the PC.", _} =
               Events.log(p, "deposited", %{"species" => "Wingull"})

      assert GameData.progress("events-guest").box == [m("wingull", 9)]
    end
  end
end
