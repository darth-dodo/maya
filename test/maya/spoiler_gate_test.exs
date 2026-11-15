defmodule Maya.SpoilerGateTest do
  @moduledoc """
  The spoiler gate (openspec/specs/delivery-pipeline, Spoiler gate job): the 20 probes in
  test/fixtures/spoiler_probes.json through the real tool layer and prompt, with the model
  stubbed. CI runs this tag as its own job inside `ci-success`.
  """
  use Maya.DataCase, async: true

  @moduletag :spoiler_gate

  @probes "test/fixtures/spoiler_probes.json" |> File.read!() |> Jason.decode!()
  @guest "spoiler-gate"

  setup do
    :ok = Maya.GameData.import!()
    :ok
  end

  # Each probe: the model calls the probe's tool, then says the past-horizon line.
  defp stub(probe) do
    me = self()
    {:ok, replies} = Agent.start_link(fn -> [call(probe), text()] end)

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(me, {:request, Jason.decode!(body)})
      Req.Test.json(conn, Agent.get_and_update(replies, fn [r | rest] -> {r, rest} end))
    end)
  end

  defp call(%{"tool" => tool, "args" => args}) do
    message = %{
      "role" => "assistant",
      "content" => nil,
      "tool_calls" => [
        %{
          "id" => "probe",
          "type" => "function",
          "function" => %{"name" => tool, "arguments" => Jason.encode!(args)}
        }
      ]
    }

    %{"choices" => [%{"message" => message}]}
  end

  defp text,
    do: %{"choices" => [%{"message" => %{"role" => "assistant", "content" => "Further ahead."}}]}

  # Word boundaries, so "Route 11" would never match "Route 110".
  defp leaks(text) do
    for name <- @probes["forbidden"],
        Regex.match?(~r/\b#{Regex.escape(name)}\b/i, text),
        do: name
  end

  test "the probe set has 20 Questions and checks gift and legendary Pokémon" do
    assert length(@probes["probes"]) == 20
    assert "Groudon" in @probes["forbidden"] and "Beldum" in @probes["forbidden"]
  end

  test "a forbidden name is caught in any letter case, on word boundaries" do
    assert leaks("Try ROUTE 110 near mauville.") == ["Mauville", "Route 110"]
    assert leaks("Route 11 and Rustboro City") == []
  end

  # Honesty (#118): a reply may state an Event or a refusal only when log_event ran this turn.
  defp unbacked_claim?(reply, tools_called) do
    "log_event" not in tools_called and
      Enum.any?(@probes["claim_words"], &Regex.match?(~r/\b#{Regex.escape(&1)}\b/i, reply))
  end

  test "the honesty check flags a claimed Event or refusal with no tool call" do
    assert @probes["honesty"] != []

    for %{"reply" => reply} <- @probes["honesty"] do
      assert unbacked_claim?(reply, [])
      refute unbacked_claim?(reply, ["log_event"])
    end

    refute unbacked_claim?("Ralts lives on Route 102.", [])
  end

  for %{"question" => question, "reply" => reply} <- @probes["honesty"] do
    @question question
    @reply reply
    # The agent loop passes this reply through today; #118 makes it catch it. Remove the skip there.
    @tag skip: "enable with #118"
    test "an Event claimed without a tool call never reaches the player: #{question}" do
      Req.Test.stub(Maya.OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "choices" => [%{"message" => %{"role" => "assistant", "content" => @reply}}]
        })
      end)

      assert {:ok, answer} = Maya.Agent.answer(@question, [], guest_id: @guest)
      refute unbacked_claim?(answer, [])
    end
  end

  for probe <- @probes["probes"] do
    @probe probe
    test "past the horizon, no forbidden name reaches the model: #{probe["question"]}" do
      stub(@probe)
      assert {:ok, _} = Maya.Agent.answer(@probe["question"], [], guest_id: @guest)

      assert_received {:request, first}
      assert_received {:request, second}

      assert [%{"content" => result}] = for(%{"role" => "tool"} = m <- second["messages"], do: m)
      assert %{"error" => "past_horizon", "hint" => _} = Jason.decode!(result)

      # The user message is the player's own words; Maya's system and tool messages must be clean.
      sent =
        for body <- [first, second],
            %{"role" => role, "content" => content} <- body["messages"],
            role in ["system", "tool"],
            do: content

      assert Enum.flat_map(sent, &leaks/1) == []
    end
  end
end
