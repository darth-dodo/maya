defmodule Mix.Tasks.Maya.SundayTest do
  use ExUnit.Case, async: false

  test "prints the Sunday goal phone checklist and the latency SQL" do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

    Mix.Tasks.Maya.Sunday.run([])

    assert_received {:mix_shell, :info, [out]}

    for item <- [
          "How do I earn Roxanne's badge?",
          "Nosepass",
          "Where do I catch a Ralts?",
          "Route 102",
          "10 holds",
          "under 8 s",
          "mix maya.latency",
          "percentile_disc(0.95) within group (order by agent_ms)",
          "percentile_disc(0.95) within group (order by playback_start_ms)",
          "from turns where not cut;"
        ],
        do: assert(out =~ item, "missing: #{item}")
  end
end
