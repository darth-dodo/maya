defmodule Maya.Voice.SSE do
  @moduledoc """
  Pure parser for the server-sent events of a Voxtral TTS stream
  (https://docs.mistral.ai/studio/audio/text-to-speech/stream-speech).
  """

  @doc """
  Parses the complete events in `buffer`. Returns `{events, rest}`, where each event is
  `{type, data}` and `rest` is an incomplete event to prepend to the next chunk.
  """
  @spec parse(binary()) :: {[{String.t(), map()}], binary()}
  def parse(buffer) do
    blocks = buffer |> String.replace("\r\n", "\n") |> String.split("\n\n")
    {complete, [rest]} = Enum.split(blocks, -1)
    {Enum.flat_map(complete, &event/1), rest}
  end

  defp event(block) do
    lines = String.split(block, "\n")
    name = Enum.find_value(lines, &field(&1, "event"))
    data = lines |> Enum.map(&field(&1, "data")) |> Enum.reject(&is_nil/1) |> Enum.join("\n")

    case Jason.decode(data) do
      {:ok, %{} = json} -> [{name || json["type"], json}]
      _ -> []
    end
  end

  defp field(line, key) do
    case String.split(line, ":", parts: 2) do
      [^key, value] -> String.trim_leading(value)
      _ -> nil
    end
  end
end
