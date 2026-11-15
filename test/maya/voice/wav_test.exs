defmodule Maya.Voice.WavTest do
  use ExUnit.Case, async: true

  test "wraps 16-bit mono PCM in a 44 byte RIFF header" do
    pcm = <<1, 0, 2, 0, 3, 0>>

    assert <<"RIFF", 42::little-32, "WAVE", "fmt ", 16::little-32, 1::little-16, 1::little-16,
             16_000::little-32, 32_000::little-32, 2::little-16, 16::little-16, "data",
             6::little-32, ^pcm::binary>> = Maya.Voice.Wav.wrap(pcm, 16_000)
  end
end
