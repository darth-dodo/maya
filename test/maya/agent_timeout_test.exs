defmodule Maya.AgentTimeoutTest do
  # Not async: it shortens the agent budget in the app env.
  use Maya.DataCase, async: false

  test "the whole agent stage shares one budget, so slow rounds end in a timeout" do
    :ok = Maya.GameData.import!()
    voice = Application.fetch_env!(:maya, :voice)
    Application.put_env(:maya, :voice, Keyword.put(voice, :agent_timeout_ms, 50))
    on_exit(fn -> Application.put_env(:maya, :voice, voice) end)

    call = %{
      "id" => "slow",
      "type" => "function",
      "function" => %{"name" => "gym_counter", "arguments" => ~s({"leader":"Roxanne"})}
    }

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      Process.sleep(80)
      message = %{"role" => "assistant", "content" => nil, "tool_calls" => [call]}
      Req.Test.json(conn, %{"choices" => [%{"message" => message}]})
    end)

    assert Maya.Agent.answer("How do I earn Roxanne's badge?", [], guest_id: "timeout") ==
             {:error, :timeout}
  end

  test "a corrective request that runs out of time gives the fallback line (#118)" do
    :ok = Maya.GameData.import!()
    voice = Application.fetch_env!(:maya, :voice)
    Application.put_env(:maya, :voice, Keyword.put(voice, :agent_timeout_ms, 200))
    on_exit(fn -> Application.put_env(:maya, :voice, voice) end)
    {:ok, sent} = Elixir.Agent.start_link(fn -> 0 end)

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      # The first reply is a rejected claim; the corrective request is too slow.
      if Elixir.Agent.get_and_update(sent, &{&1, &1 + 1}) > 0, do: Process.sleep(300)
      content = Jason.encode!(%{answer: "I refused Ralts.", used_tool_calls: []})

      Req.Test.json(conn, %{
        "choices" => [%{"message" => %{"role" => "assistant", "content" => content}}]
      })
    end)

    assert Maya.Agent.answer("Add Ralts", [], guest_id: "timeout") ==
             {:ok, "Not sure I got that right, ask me again?"}
  end
end
