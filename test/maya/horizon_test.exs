defmodule Maya.HorizonTest do
  use ExUnit.Case, async: true

  alias Maya.Horizon

  @no_badges %{badges: []}
  @one_badge %{badges: [1]}

  describe "next_gym/1" do
    test "with 0 badges it is Roxanne in Rustboro City" do
      assert %{badge: 1, leader: "Roxanne", city: "Rustboro City"} = Horizon.next_gym(@no_badges)
    end

    test "with 1 badge it is Brawly" do
      assert %{badge: 2, leader: "Brawly"} = Horizon.next_gym(@one_badge)
    end

    test "with all 8 badges there is none" do
      assert Horizon.next_gym(%{badges: Enum.to_list(1..8)}) == nil
    end
  end

  describe "badges_earned/1" do
    test "counts distinct badges 1 to 8" do
      assert Horizon.badges_earned(@no_badges) == 0
      assert Horizon.badges_earned(%{badges: [1, 1]}) == 1
      assert Horizon.badges_earned(%{badges: [1, 9, 0]}) == 1
    end
  end

  describe "allowed?/2" do
    test "Rustboro City is allowed at 0 badges" do
      assert Horizon.allowed?(%{name: "Rustboro City", badges_required: 0}, @no_badges)
    end

    test "a location needing a badge waits for that badge" do
      location = %{name: "Dewford Town", badges_required: 1}
      refute Horizon.allowed?(location, @no_badges)
      assert Horizon.allowed?(location, @one_badge)
    end

    test "an unlisted location is never allowed (fail closed)" do
      refute Horizon.allowed?(nil, @no_badges)
      refute Horizon.allowed?(nil, @one_badge)
      refute Horizon.allowed?("Route 111", @one_badge)
      refute Horizon.allowed?(%{name: "Route 111"}, @one_badge)
    end
  end

  test "gyms/0 lists the 8 gyms in badge order" do
    assert Enum.map(Horizon.gyms(), & &1.badge) == Enum.to_list(1..8)
  end

  describe "level_cap/2" do
    defp team(level), do: [%{"species" => "mudkip", "level" => level}]

    test "at 0 badges it is the Next gym ace's level" do
      assert Horizon.level_cap(%{badges: [], team: team(5)}, 15) == 15
    end

    test "a Team member above the ace raises it" do
      assert Horizon.level_cap(%{badges: [], team: team(20)}, 15) == 20
    end

    test "a missing ace before the last gym keeps the Team's level as the cap" do
      assert Horizon.level_cap(%{badges: [], team: team(5)}, nil) == 5
    end

    test "a Team member without a level never removes the cap" do
      progress = %{badges: [], team: [%{"species" => "mudkip"} | team(5)]}
      assert Horizon.level_cap(progress, 15) == 15
    end

    test "with all 8 badges there is none" do
      assert Horizon.level_cap(%{badges: Enum.to_list(1..8), team: team(50)}, nil) == nil
    end
  end
end
