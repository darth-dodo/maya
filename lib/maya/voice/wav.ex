defmodule Maya.Voice.Wav do
  @moduledoc "Wraps streamed 16-bit mono PCM in a 44 byte RIFF header, so batch STT gets a file."

  def wrap(pcm, rate) do
    size = byte_size(pcm)

    <<"RIFF", 36 + size::little-32, "WAVE", "fmt ", 16::little-32, 1::little-16, 1::little-16,
      rate::little-32, rate * 2::little-32, 2::little-16, 16::little-16, "data", size::little-32,
      pcm::binary>>
  end
end
