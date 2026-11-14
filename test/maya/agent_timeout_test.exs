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

    assert Maya.Agent.answer("How do I earn Roxanne's badge?", []) == {:error, :timeout}
  end
end
