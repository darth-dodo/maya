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
        Req.Test.json(conn, %{
          "choices" => [
            %{"message" => %{"role" => "assistant", "content" => "Lead with Mudkip."}}
          ]
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
end
