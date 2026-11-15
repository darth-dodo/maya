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
end
