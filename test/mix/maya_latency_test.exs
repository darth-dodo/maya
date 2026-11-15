defmodule Mix.Tasks.Maya.LatencyTest do
  use Maya.DataCase, async: false

  alias Maya.Voice.Turn

  test "prints p50 and p95 per stage from the stored turns" do
    for ms <- [100, 200, 300, 400, 500],
        do: {:ok, _} = Turn.insert(%Turn{guest_id: "g", question: "q", answer: "a", stt_ms: ms})

    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

    Mix.Tasks.Maya.Latency.run([])

    assert_received {:mix_shell, :info, [out]}
    assert out =~ ~r/stt_ms\s+n=5 p50=300 p95=500/
    assert out =~ ~r/playback_start_ms\s+missing/
  end
end
