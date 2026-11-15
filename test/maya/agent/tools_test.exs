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

    assert Enum.sort(names) == ["find_pokemon", "gym_counter"]
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

  test "wrong arguments and unknown tools are errors, not crashes", %{progress: progress} do
    assert Tools.call("gym_counter", %{"name" => 1}, progress) == {:error, :bad_arguments}
    assert Tools.call("log_event", %{}, progress) == {:error, :unknown_tool}
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
end
