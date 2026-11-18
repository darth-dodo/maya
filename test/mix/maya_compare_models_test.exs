defmodule Mix.Tasks.Maya.CompareModelsTest do
  use Maya.DataCase, async: false

  test "prints one line per model with its milliseconds and Answer" do
    :ok = Maya.GameData.import!()

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      %{"model" => model} = Jason.decode!(body)

      if model == "model-b" do
        Plug.Conn.send_resp(conn, 503, "down")
      else
        content = Jason.encode!(%{answer: "Lead with Mudkip.", used_tool_calls: []})

        Req.Test.json(conn, %{
          "choices" => [%{"message" => %{"role" => "assistant", "content" => content}}]
        })
      end
    end)

    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

    Mix.Tasks.Maya.CompareModels.run(["model-a", "model-b"])

    assert_received {:mix_shell, :info, [a]}
    assert a =~ ~r/^model-a  \d+ ms  Lead with Mudkip\.$/
    assert_received {:mix_shell, :info, [b]}
    assert b =~ ~r/^model-b  \d+ ms  error: \{:http, 503\}$/
  end

  test "without a key, every ADR-007 candidate reports the missing key" do
    :ok = Maya.GameData.import!()
    config = Application.fetch_env!(:maya, :openrouter)
    Application.put_env(:maya, :openrouter, Keyword.put(config, :api_key, nil))
    on_exit(fn -> Application.put_env(:maya, :openrouter, config) end)

    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

    Mix.Tasks.Maya.CompareModels.run([])

    for model <- ["anthropic/claude-haiku-5.5", "google/gemini-3.8-flash", "openai/gpt-5.4-mini"] do
      assert_received {:mix_shell, :info, [line]}
      assert line =~ ~r/^#{Regex.escape(model)}  \d+ ms  error: :no_api_key$/
    end
  end
end
