defmodule Maya.Agent.TraceTest do
  # Not async: it points the one global batch processor at this test's exporter.
  use Maya.DataCase, async: false

  import ExUnit.CaptureLog
  require OpenTelemetry.Tracer, as: Tracer
  require Record

  alias Maya.Agent

  Record.defrecordp(:span, Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl"))

  @guest "trace-guest-7f3a"
  @question "Where is the secret Question text about Zigzagoon?"
  @answer "The secret Answer text says hello there."

  setup do
    :ok = Maya.GameData.import!()
    :ok = :otel_batch_processor.set_exporter(:otel_exporter_pid, self())
    # `set_exporter/2` has no `:none`, so later tests export to a dead pid: nowhere.
    on_exit(fn ->
      :otel_batch_processor.set_exporter(:otel_exporter_pid, spawn(fn -> :ok end))
    end)
  end

  defp script(replies) do
    {:ok, agent} = Elixir.Agent.start_link(fn -> replies end)

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      Req.Test.json(
        conn,
        Elixir.Agent.get_and_update(agent, fn
          [r] -> {r, [r]}
          [r | rest] -> {r, rest}
        end)
      )
    end)
  end

  defp usage(prompt, cached, completion),
    do: %{
      "prompt_tokens" => prompt,
      "completion_tokens" => completion,
      "prompt_tokens_details" => %{"cached_tokens" => cached}
    }

  defp text(answer, ids, usage \\ nil),
    do: %{
      "choices" => [
        %{
          "message" => %{
            "role" => "assistant",
            "content" => Jason.encode!(%{answer: answer, used_tool_calls: ids})
          }
        }
      ],
      "usage" => usage
    }

  defp calls(calls, usage \\ nil) do
    tool_calls =
      for {id, name, args} <- calls,
          do: %{
            "id" => id,
            "type" => "function",
            "function" => %{"name" => name, "arguments" => args}
          }

    %{
      "choices" => [
        %{"message" => %{"role" => "assistant", "content" => nil, "tool_calls" => tool_calls}}
      ],
      "usage" => usage
    }
  end

  # One Question under a test root span, so `spans/0` keeps only this test's trace: in CI,
  # Tasks left over from async tests can end spans while this module runs.
  defp answer(question, turns, opts) do
    Tracer.with_span "test" do
      Process.put(:trace_id, OpenTelemetry.Span.trace_id(Tracer.current_span_ctx()))
      Agent.answer(question, turns, opts)
    end
  end

  # Every span this test's turn ended, with its attributes as a map.
  defp spans do
    :otel_tracer_provider.force_flush()
    trace = Process.get(:trace_id)
    for s <- collect([]), s.trace == trace, s.name != "test", do: s
  end

  defp collect(acc) do
    receive do
      {:span, s} ->
        collect([
          %{
            trace: span(s, :trace_id),
            name: span(s, :name),
            id: span(s, :span_id),
            parent: span(s, :parent_span_id),
            start: span(s, :start_time),
            end: span(s, :end_time),
            attrs: :otel_attributes.map(span(s, :attributes))
          }
          | acc
        ])
    after
      300 -> Enum.reverse(acc)
    end
  end

  defp named(spans, name), do: Enum.filter(spans, &(&1.name == name))

  test "two rounds with one tool call: a turn span, 2 round spans, 1 tool span under round 1" do
    script([
      calls([{"c1", "find_pokemon", ~s({"name":"Ralts"})}], usage(450, 300, 20)),
      text("Ralts lives in the grass on Route 102.", ["c1"], usage(450, 300, 20))
    ])

    Logger.put_module_level(Maya.Agent, :info)
    on_exit(fn -> Logger.delete_module_level(Maya.Agent) end)

    log =
      capture_log([level: :info], fn ->
        assert {:ok, _} = answer("Where do I catch a Ralts?", [], guest_id: @guest)
      end)

    spans = spans()
    assert [turn] = named(spans, "turn")
    assert [r1, r2] = named(spans, "round") |> Enum.sort_by(& &1.attrs["maya.round"])
    assert [tool] = named(spans, "tool")

    assert r1.parent == turn.id and r2.parent == turn.id
    assert tool.parent == r1.id
    for s <- [turn, r1, r2, tool], do: assert(s.end >= s.start)

    assert turn.attrs["gen_ai.request.model"] == "anthropic/claude-haiku-5.5"
    assert turn.attrs["maya.rounds"] == 2
    assert turn.attrs["maya.prompt_tokens"] == 900
    assert turn.attrs["maya.cached_tokens"] == 600
    assert turn.attrs["maya.completion_tokens"] == 40
    assert turn.attrs["maya.honesty"] == :ok
    refute Map.has_key?(turn.attrs, "maya.reason")

    # The same numbers as the turn log line (#212).
    assert log =~ "rounds=2 history=0 prompt_tokens=900 cached_tokens=600"

    assert r1.attrs["gen_ai.usage.input_tokens"] == 450
    assert r1.attrs["gen_ai.usage.output_tokens"] == 20
    assert r1.attrs["maya.cached_tokens"] == 300
    assert tool.attrs == %{"gen_ai.tool.name" => "find_pokemon", "maya.tool.status" => :ok}
  end

  test "tool status atoms: not_found, past_horizon, refused, error, and a made-up name" do
    script([
      calls([
        {"a", "find_pokemon", ~s({"name":"Agumon"})},
        {"b", "type_matchup", ~s({"defender":"Wattson"})},
        {"c", "set_setting", ~s({"name":"humor","value":120})},
        {"d", "find_pokemon", "not json"},
        {"e", "the secret tool", "{}"}
      ]),
      text("Not sure.", [])
    ])

    assert {:ok, _} = answer("Several things", [], guest_id: @guest)

    statuses =
      for t <- named(spans(), "tool"),
          do: {t.attrs["gen_ai.tool.name"], t.attrs["maya.tool.status"]}

    assert Enum.sort(statuses) ==
             Enum.sort([
               {"find_pokemon", :not_found},
               {"type_matchup", :past_horizon},
               {"set_setting", :refused},
               {"find_pokemon", :error},
               {"unknown", :error}
             ])
  end

  test "a turn that runs out of time has reason timeout" do
    voice = Application.fetch_env!(:maya, :voice)
    Application.put_env(:maya, :voice, Keyword.put(voice, :agent_timeout_ms, 50))
    on_exit(fn -> Application.put_env(:maya, :voice, voice) end)

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      Process.sleep(80)
      Req.Test.json(conn, calls([{"slow", "gym_counter", ~s({"leader":"Roxanne"})}]))
    end)

    assert answer("Roxanne?", [], guest_id: @guest) == {:error, :timeout}
    assert [turn] = named(spans(), "turn")
    assert turn.attrs["maya.reason"] == :timeout
  end

  test "no attribute holds the Question, Answer, guest id or tool arguments" do
    script([
      calls([{"c1", "search_guide", ~s({"location":"Petalburg Woods secret place"})}]),
      text(@answer, ["c1"])
    ])

    assert {:ok, @answer} = answer(@question, [], guest_id: @guest)

    spans = spans()
    assert length(spans) == 4
    values = for s <- spans, v <- Map.values(s.attrs), do: v

    for v <- values do
      assert is_integer(v) or is_atom(v) or
               v in ["anthropic/claude-haiku-5.5", "search_guide", "unknown"]
    end

    text = Enum.map_join(values, " ", &to_string/1)

    for secret <- ["secret", "Zigzagoon", "hello", @guest, "Petalburg"],
        do: refute(text =~ secret)
  end

  test "an export to a refused port never delays or fails the turn" do
    :ok =
      :otel_batch_processor.set_exporter(:opentelemetry_exporter, %{
        protocol: :http_protobuf,
        endpoints: ["http://localhost:1/v1/traces"]
      })

    script([text("Hi there.", []), text("Hi again.", [])])

    {us, result} = :timer.tc(fn -> Agent.answer("Hi", [], guest_id: @guest) end)
    assert result == {:ok, "Hi there."}
    # Stubbed turns take a few ms; an export on the turn path would add the connect attempt.
    assert us < 500_000

    :otel_tracer_provider.force_flush()
    assert {:ok, "Hi again."} = Agent.answer("Hi", [], guest_id: @guest)
  end

  test "inets starts before opentelemetry, so the OTLP exporter initializes at boot" do
    apps = Application.spec(:maya, :applications)
    assert Enum.find_index(apps, &(&1 == :inets)) < Enum.find_index(apps, &(&1 == :opentelemetry))
  end

  describe "config/runtime.exs" do
    setup do
      saved = for k <- ~w(LANGFUSE_PUBLIC_KEY LANGFUSE_SECRET_KEY), do: {k, System.get_env(k)}

      on_exit(fn ->
        for {k, v} <- saved, do: if(v, do: System.put_env(k, v), else: System.delete_env(k))
      end)
    end

    test "either key unset: no exporter" do
      for {public, secret} <- [{nil, nil}, {"pk-test", nil}, {nil, "sk-test"}, {"", "sk-test"}] do
        put("LANGFUSE_PUBLIC_KEY", public)
        put("LANGFUSE_SECRET_KEY", secret)
        config = Config.Reader.read!("config/runtime.exs", env: :dev)
        assert config[:opentelemetry] == [traces_exporter: :none]
        refute config[:opentelemetry_exporter]
      end
    end

    test "both keys set: OTLP/HTTP to Langfuse EU with Basic auth and ingestion version 4" do
      put("LANGFUSE_PUBLIC_KEY", "pk-test")
      put("LANGFUSE_SECRET_KEY", "sk-test")
      config = Config.Reader.read!("config/runtime.exs", env: :dev)

      assert config[:opentelemetry] == [span_processor: :batch, traces_exporter: :otlp]
      exporter = config[:opentelemetry_exporter]
      assert exporter[:otlp_protocol] == :http_protobuf

      assert exporter[:otlp_traces_endpoint] ==
               "https://cloud.langfuse.com/api/public/otel/v1/traces"

      assert exporter[:otlp_traces_headers] == [
               {"Authorization", "Basic " <> Base.encode64("pk-test:sk-test")},
               {"x-langfuse-ingestion-version", "4"}
             ]
    end

    defp put(k, nil), do: System.delete_env(k)
    defp put(k, v), do: System.put_env(k, v)
  end
end
