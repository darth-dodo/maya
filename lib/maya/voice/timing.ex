defmodule Maya.Voice.Timing do
  @moduledoc """
  Telemetry handler for `[:maya, :voice, stage, :stop]`
  (https://hexdocs.pm/telemetry/telemetry.html). It sends the stage milliseconds to the
  Conversation named in the metadata, which keeps them on the turn in flight. TTS first byte
  is recorded by the Conversation itself (its event carries no Conversation).
  """

  # Stage event name => turn column.
  @columns %{stt: :stt_ms, agent: :agent_ms, tts_first_byte: :tts_first_byte_ms}

  def attach do
    :telemetry.attach_many(
      __MODULE__,
      for(stage <- Map.keys(@columns), do: [:maya, :voice, stage, :stop]),
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event(
        [:maya, :voice, stage, :stop],
        %{duration: d},
        %{conversation: pid, ref: ref},
        _
      ) do
    ms = System.convert_time_unit(d, :native, :millisecond)
    send(pid, {:stage_ms, ref, Map.fetch!(@columns, stage), ms})
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok
end
