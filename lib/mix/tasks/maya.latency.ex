defmodule Mix.Tasks.Maya.Latency do
  @shortdoc "Prints p50 and p95 per voice stage over the stored turns"
  @moduledoc """
  Prints p50 and p95 (nearest rank, milliseconds) per voice stage over every `turns` row.
  Every voice-loop PR pastes this before and after.

      mix maya.latency
  """
  use Mix.Task

  @requirements ["app.start"]

  @impl true
  def run(_args) do
    Maya.Voice.Turn.stage_rows()
    |> Maya.Voice.Latency.summary()
    |> Maya.Voice.Latency.format()
    |> Mix.shell().info()
  end
end
