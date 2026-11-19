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
    {:ok, replies} = Elixir.Agent.start_link(fn -> [call(probe), text()] end)

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(me, {:request, Jason.decode!(body)})
      Req.Test.json(conn, Elixir.Agent.get_and_update(replies, fn [r | rest] -> {r, rest} end))
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

  defp text, do: answer("Further ahead.")

  defp answer(text) do
    content = Jason.encode!(%{answer: text, used_tool_calls: []})
    %{"choices" => [%{"message" => %{"role" => "assistant", "content" => content}}]}
  end

  # Word boundaries, so "Route 11" would never match "Route 110"; any letter case.
  defp word?(text, word), do: Regex.match?(~r/\b#{Regex.escape(word)}\b/i, text)

  defp leaks(text), do: for(name <- @probes["forbidden"], word?(text, name), do: name)

  test "the probe set has 20 Questions and checks gift and legendary Pokémon" do
    assert length(@probes["probes"]) == 20
    assert "Groudon" in @probes["forbidden"] and "Beldum" in @probes["forbidden"]
  end

  test "a forbidden name is caught in any letter case, on word boundaries" do
    assert leaks("Try ROUTE 110 near mauville.") == ["Mauville", "Route 110"]
    assert leaks("Route 11 and Rustboro City") == []
  end

  # Honesty (#118): a reply may state an Event, a Dial change or a refusal only when a write
  # (log_event or set_setting) ran this turn.
  # The claim words live in the app now, so the gate checks the list the loop uses.
  defp unbacked_claim?(reply, tools_called) do
    answer = %Maya.Agent.Answer{answer: reply, used_tool_calls: []}

    match?(
      {:error, {:unbacked_claim, _}},
      Maya.Agent.Answer.check(answer, Map.new(tools_called, &{&1, &1}))
    )
  end

  test "the honesty check flags a claimed Event or refusal with no tool call" do
    assert @probes["honesty"] != []

    for %{"reply" => reply} <- @probes["honesty"] do
      assert unbacked_claim?(reply, [])
      refute unbacked_claim?(reply, ["log_event"])
      refute unbacked_claim?(reply, ["set_setting"])
    end

    assert unbacked_claim?("Done, I added Ralts to your team.", [])
    assert unbacked_claim?("Done, Wingull leads your Team now.", [])
    refute unbacked_claim?("Ralts lives on Route 102.", [])
  end

  # Through the loop: the model repeats the claim, so the Answer is the fallback line, and a
  # corrected second reply is said instead. Either way the claim never reaches the player.
  for %{"question" => question, "reply" => reply} <- @probes["honesty"],
      corrected <- [nil, "Not sure, tell me again what happened."] do
    @question question
    @reply reply
    @corrected corrected
    test "an Event claimed without a tool call never reaches the player (#{if corrected, do: "corrected", else: "replaced"}): #{question}" do
      me = self()
      replies = if @corrected, do: [@reply, @corrected], else: [@reply, @reply]
      {:ok, left} = Elixir.Agent.start_link(fn -> replies end)

      Req.Test.stub(Maya.OpenRouter, fn conn ->
        send(me, :request)

        Req.Test.json(
          conn,
          answer(Elixir.Agent.get_and_update(left, fn [r | rest] -> {r, rest} end))
        )
      end)

      assert {:ok, said} = Maya.Agent.answer(@question, [], guest_id: @guest)
      refute unbacked_claim?(said, [])
      assert said == (@corrected || "Not sure I got that right, ask me again?")
      for _ <- 1..2, do: assert_received(:request)
      refute_received :request
    end
  end

  # The system and tool messages, which are Maya's own words; the user message is the player's.
  defp sent(bodies) do
    for body <- bodies,
        %{"role" => role, "content" => content} <- body["messages"],
        role in ["system", "tool"],
        do: content
  end

  test "the move probes cover a Fact and two past-horizon species" do
    assert Enum.map(@probes["move_probes"], & &1["expect"]) == [
             "fact",
             "past_horizon",
             "past_horizon"
           ]

    assert "Foresight" in hd(@probes["move_probes"])["forbidden"]
  end

  for probe <- @probes["move_probes"] do
    @probe probe
    test "no move past the level horizon reaches the model: #{probe["question"]}" do
      stub(@probe)
      assert {:ok, _} = Maya.Agent.answer(@probe["question"], [], guest_id: @guest)

      assert_received {:request, first}
      assert_received {:request, second}
      assert [%{"content" => result}] = for(%{"role" => "tool"} = m <- second["messages"], do: m)

      case @probe["expect"] do
        "fact" -> assert %{"fact" => %{"moves" => [_ | _]}} = Jason.decode!(result)
        "past_horizon" -> assert %{"error" => "past_horizon", "hint" => _} = Jason.decode!(result)
      end

      forbidden = @probes["forbidden"] ++ @probe["forbidden"]
      leaked = for text <- sent([first, second]), name <- forbidden, word?(text, name), do: name
      assert leaked == []
    end
  end

  test "the guide probes cover 0, 1 and 2 badges" do
    assert @probes["guide_probes"] |> Enum.map(& &1["badges"]) |> Enum.uniq() == [[], [1], [1, 2]]
  end

  for probe <- @probes["guide_probes"] do
    @probe probe
    test "a guide answer names nothing past #{length(probe["badges"])} badges: #{probe["question"]}" do
      Maya.GameData.progress(@guest)

      Repo.query!("UPDATE progress SET badges = $1, location = $2 WHERE guest_id = $3", [
        @probe["badges"],
        @probe["location"],
        @guest
      ])

      stub(@probe)
      assert {:ok, _} = Maya.Agent.answer(@probe["question"], [], guest_id: @guest)

      assert_received {:request, first}
      assert_received {:request, second}
      assert [%{"content" => result}] = for(%{"role" => "tool"} = m <- second["messages"], do: m)

      case @probe["expect"] do
        "fact" -> assert %{"fact" => %{"note" => _}} = Jason.decode!(result)
        "past_horizon" -> assert %{"error" => "past_horizon", "hint" => _} = Jason.decode!(result)
        "refused" -> assert %{"refused" => "Spoilers stay at 0" <> _} = Jason.decode!(result)
      end

      global = if @probe["badges"] == [], do: @probes["forbidden"], else: []
      forbidden = global ++ @probe["forbidden"]
      leaked = for text <- sent([first, second]), name <- forbidden, word?(text, name), do: name
      assert leaked == []
    end
  end

  test "the place probes cover find_trainer and find_item at 0, 1 and 2 badges" do
    probes = @probes["place_probes"]
    assert probes |> Enum.map(& &1["badges"]) |> Enum.uniq() == [[], [1], [1, 2]]

    assert probes |> Enum.map(& &1["tool"]) |> Enum.uniq() |> Enum.sort() == [
             "find_item",
             "find_trainer"
           ]
  end

  for probe <- @probes["place_probes"] do
    @probe probe
    test "a trainer or item answer names nothing past #{length(probe["badges"])} badges: #{probe["question"]}" do
      Maya.GameData.progress(@guest)

      Repo.query!("UPDATE progress SET badges = $1, location = $2 WHERE guest_id = $3", [
        @probe["badges"],
        @probe["location"],
        @guest
      ])

      stub(@probe)
      assert {:ok, _} = Maya.Agent.answer(@probe["question"], [], guest_id: @guest)

      assert_received {:request, first}
      assert_received {:request, second}
      assert [%{"content" => result}] = for(%{"role" => "tool"} = m <- second["messages"], do: m)

      case @probe["expect"] do
        "fact" -> assert %{"fact" => %{}} = Jason.decode!(result)
        "past_horizon" -> assert %{"error" => "past_horizon", "hint" => _} = Jason.decode!(result)
      end

      global = if @probe["badges"] == [], do: @probes["forbidden"], else: []
      forbidden = global ++ @probe["forbidden"]
      leaked = for text <- sent([first, second]), name <- forbidden, word?(text, name), do: name
      assert leaked == []
    end
  end

  test "the Team probes cover set_team, deposited and set_level" do
    kinds = for %{"args" => %{"kind" => kind}} <- @probes["team_probes"], do: kind
    assert kinds == ["set_team", "deposited", "set_level", "set_level"]
  end

  # The species a Team probe's Question names, from its log_event details.
  defp named_species(%{"details" => %{"team" => team}}),
    do: Enum.map(team, &String.downcase(&1["species"]))

  defp named_species(%{"details" => %{"species" => species}}), do: [String.downcase(species)]

  for probe <- @probes["team_probes"] do
    @probe probe
    test "Team probes pass the spoiler gate, naming only what the Question named: #{probe["question"]}" do
      progress = Maya.GameData.progress(@guest)
      if team = @probe["team"], do: Maya.GameData.put_progress!(%{progress | team: team})

      stub(@probe)
      assert {:ok, _} = Maya.Agent.answer(@probe["question"], [], guest_id: @guest)

      assert_received {:request, first}
      assert_received {:request, second}
      assert [%{"content" => result}] = for(%{"role" => "tool"} = m <- second["messages"], do: m)
      assert %{"confirm" => line} = Jason.decode!(result)

      said = for s <- Maya.GameData.species_names(), word?(line, s), do: s
      assert said -- named_species(@probe["args"]) == []
      assert [first, second] |> sent() |> Enum.flat_map(&leaks/1) == []
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

      assert [first, second] |> sent() |> Enum.flat_map(&leaks/1) == []
    end
  end
end
