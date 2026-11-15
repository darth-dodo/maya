defmodule Mix.Tasks.Maya.Sunday do
  @shortdoc "Prints the Sunday goal phone checklist and the latency SQL"
  @moduledoc """
  Prints what Abhishek runs on the phone for the Sunday goal (Issue #40) and the latency SQL
  for the Supabase SQL editor. Static text, so it needs no database.

      mix maya.sunday
  """
  use Mix.Task

  @checklist """
  Sunday goal, on the phone (https://maya-j56u.onrender.com/talk):

  1. Hold and ask "How do I earn Roxanne's badge?": the Answer names Nosepass and a Team counter.
  2. Hold and ask "Where do I catch a Ralts?": the Answer names Route 102.
  3. 10 holds in a row make exactly 10 Questions.
  4. Answer time under 8 s for both Questions (p50 and p95).
  5. Paste the numbers on #40: `mix maya.latency`, or this SQL in the Supabase SQL editor:

  select count(*) as turns,
    percentile_disc(0.5)  within group (order by mic_release_ms)    as mic_p50,
    percentile_disc(0.95) within group (order by mic_release_ms)    as mic_p95,
    percentile_disc(0.5)  within group (order by stt_ms)            as stt_p50,
    percentile_disc(0.95) within group (order by stt_ms)            as stt_p95,
    percentile_disc(0.5)  within group (order by agent_ms)          as agent_p50,
    percentile_disc(0.95) within group (order by agent_ms)          as agent_p95,
    percentile_disc(0.5)  within group (order by tts_first_byte_ms) as tts_p50,
    percentile_disc(0.95) within group (order by tts_first_byte_ms) as tts_p95,
    percentile_disc(0.5)  within group (order by playback_start_ms) as play_p50,
    percentile_disc(0.95) within group (order by playback_start_ms) as play_p95
  from turns where not cut;
  """

  @impl true
  def run(_args), do: Mix.shell().info(@checklist)
end
