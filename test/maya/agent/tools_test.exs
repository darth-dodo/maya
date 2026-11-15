defmodule Maya.Agent.ToolsTest do
  use Maya.DataCase, async: true

  alias Maya.Agent.Tools
  alias Maya.GameData

  setup do
    :ok = GameData.import!()
    %{progress: GameData.progress("tools-test")}
  end

  test "every tool has an OpenAI-style function definition" do
    names =
      for %{type: "function", function: %{name: n, parameters: %{type: "object"}}} <-
            Tools.definitions(),
          do: n

    assert Enum.sort(names) == ["find_pokemon", "gym_counter", "log_event", "move_learnset"]
  end

  test "gym_counter for Roxanne from the imported data and the seed Team", %{progress: progress} do
    assert {:ok, fact} = Tools.call("gym_counter", %{"leader" => "Roxanne"}, progress)
    assert %{species: "nosepass", level: 15} = fact.ace
    assert fact.suggested_lead == "mudkip"
    assert [%{species: "mudkip", vs_ace: 2.0}] = fact.team
  end

  test "gym_counter past the horizon and unknown", %{progress: progress} do
    assert Tools.call("gym_counter", %{"leader" => "Wattson"}, progress) ==
             {:error, :past_horizon}

    assert Tools.call("gym_counter", %{"leader" => "Giovanni"}, progress) == {:error, :not_found}
  end

  test "find_pokemon for Ralts lists Route 102 only", %{progress: progress} do
    assert {:ok, %{types: ["psychic"], places: places}} =
             Tools.call("find_pokemon", %{"name" => "Ralts"}, progress)

    assert [%{location: "Route 102", method: "land", rate: 4}] = places
  end

  test "find_pokemon past the horizon and unknown", %{progress: progress} do
    assert Tools.call("find_pokemon", %{"name" => "Zubat"}, progress) == {:error, :past_horizon}
    assert Tools.call("find_pokemon", %{"name" => "Agumon"}, progress) == {:error, :not_found}
  end

  test "move_learnset for Mudkip stops at Roxanne's ace, level 15", %{progress: progress} do
    assert {:ok, %{name: "mudkip", level_horizon: 15, moves: moves}} =
             Tools.call("move_learnset", %{"species" => "Mudkip"}, progress)

    assert Enum.map(moves, &{&1.move, &1.level}) == [
             {"tackle", 1},
             {"growl", 1},
             {"mud-slap", 6},
             {"water-gun", 10},
             {"bide", 15}
           ]
  end

  test "move_learnset with every badge lists Endeavor", %{progress: progress} do
    progress = %{progress | badges: Enum.to_list(1..8)}

    assert {:ok, %{level_horizon: nil, moves: moves}} =
             Tools.call("move_learnset", %{"species" => "mudkip"}, progress)

    assert "endeavor" in Enum.map(moves, & &1.move)
  end

  test "move_learnset past the horizon, unknown and without species", %{progress: progress} do
    for name <- ["Groudon", "Marshtomp"] do
      assert Tools.call("move_learnset", %{"species" => name}, progress) ==
               {:error, :past_horizon}
    end

    assert Tools.call("move_learnset", %{"species" => "Agumon"}, progress) ==
             {:error, :not_found}

    assert Tools.call("move_learnset", %{}, progress) == {:error, :bad_arguments}
  end

  test "wrong arguments and unknown tools are errors, not crashes", %{progress: progress} do
    assert Tools.call("gym_counter", %{"name" => 1}, progress) == {:error, :bad_arguments}
    assert Tools.call("set_setting", %{}, progress) == {:error, :unknown_tool}
    assert Tools.call("log_event", %{"kind" => 1}, progress) == {:error, :bad_arguments}
  end

  test "results are encoded as JSON for the model, past horizon with a hint", %{
    progress: progress
  } do
    assert %{"fact" => %{"suggested_lead" => "mudkip"}} =
             Tools.call("gym_counter", %{"leader" => "Roxanne"}, progress)
             |> Tools.encode(progress)
             |> Jason.decode!()

    assert %{"error" => "past_horizon", "hint" => hint} =
             Jason.decode!(Tools.encode({:error, :past_horizon}, progress))

    assert hint =~ "Roxanne"
    assert %{"error" => "not_found"} = Jason.decode!(Tools.encode({:error, :not_found}, progress))
  end

  test "log_event writes the Event and returns the new Progress with its confirm line", %{
    progress: progress
  } do
    args = %{"kind" => "badge_earned", "details" => %{"leader" => "Roxanne"}}

    assert {:logged, "Stone Badge logged. Mudkip would approve.", %{badges: [1]}} =
             result = Tools.call("log_event", args, progress)

    assert Jason.decode!(Tools.encode(result, progress)) == %{
             "confirm" => "Stone Badge logged. Mudkip would approve."
           }

    assert GameData.progress("tools-test").badges == [1]
  end

  test "log_event refusals are a line for the model; details may be left out", %{
    progress: progress
  } do
    refused = Tools.call("log_event", %{"kind" => "badge_earned"}, progress)
    assert refused == {:refused, "I can only log Roxanne's badge next."}
    assert Jason.decode!(Tools.encode(refused, progress)) == %{"refused" => elem(refused, 1)}
  end
end
