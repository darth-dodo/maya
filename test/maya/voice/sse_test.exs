defmodule Maya.Voice.SSETest do
  use ExUnit.Case, async: true

  alias Maya.Voice.SSE

  @delta ~s(event: speech.audio.delta\ndata: {"type":"speech.audio.delta","audio_data":"AAE="}\n\n)
  @done ~s(event: speech.audio.done\ndata: {"type":"speech.audio.done","usage":{}}\n\n)

  test "parses whole events and keeps nothing" do
    assert {[{"speech.audio.delta", %{"audio_data" => "AAE="}}, {"speech.audio.done", _}], ""} =
             SSE.parse(@delta <> @done)
  end

  test "keeps a partial event for the next chunk" do
    {cut, rest_of_delta} = String.split_at(@delta, 20)

    assert {[], ^cut} = SSE.parse(cut)

    assert {[{"speech.audio.delta", %{"audio_data" => "AAE="}}], ""} =
             SSE.parse(cut <> rest_of_delta)
  end

  test "every split point yields each event exactly once, in order" do
    stream = @delta <> @delta <> @done

    for at <- 1..(byte_size(stream) - 1) do
      <<a::binary-size(^at), b::binary>> = stream
      {first, rest} = SSE.parse(a)
      {second, ""} = SSE.parse(rest <> b)

      assert Enum.map(first ++ second, &elem(&1, 0)) ==
               ~w(speech.audio.delta speech.audio.delta speech.audio.done)
    end
  end

  test "takes the type from data when there is no event line, and accepts CRLF" do
    assert {[{"speech.audio.done", _}], ""} =
             SSE.parse(~s(data: {"type":"speech.audio.done"}\r\n\r\n))
  end

  test "skips comments and data that is not JSON" do
    assert {[], ""} = SSE.parse(": keep-alive\n\ndata: [DONE]\n\n")
  end
end
