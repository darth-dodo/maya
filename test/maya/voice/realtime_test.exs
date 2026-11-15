defmodule Maya.Voice.RealtimeTest do
  # Not async: each test points the relay URL (app config) at its own fake endpoint.
  use ExUnit.Case, async: false

  alias Maya.FakeMistralRealtime
  alias Maya.Voice.Realtime

  @terms ["Maya", "Mudkip", "Roxanne"]

  defp start_relay do
    ref = make_ref()
    {pid, _mon} = Realtime.start(self(), ref, @terms)
    {pid, ref}
  end

  test "sends the session settings before any audio, relays chunks in order and reports text" do
    FakeMistralRealtime.serve(:ok)
    {relay, ref} = start_relay()

    for chunk <- ~w(AAA= BBB= CCC=), do: send(relay, {:audio, chunk})
    send(relay, :end)

    assert_receive {:fake_request, request}
    assert request.path == "/v1/audio/transcriptions/realtime"
    assert request.model == "voxtral-mini-transcribe-realtime-3"
    assert request.auth == ["Bearer test-key"]

    assert_receive {:fake_got, %{"type" => "session.update", "session" => session}}

    assert session == %{
             "audio_format" => %{"encoding" => "pcm_s16le", "sample_rate" => 16_000},
             "language" => "en",
             "context_bias" => @terms,
             "target_streaming_delay_ms" => 480
           }

    for chunk <- ~w(AAA= BBB= CCC=),
        do: assert_receive({:fake_got, %{"type" => "input_audio.append", "audio" => ^chunk}})

    assert_receive {:fake_got, %{"type" => "input_audio.end"}}

    assert_receive {:partial, ^ref, "where do"}
    assert_receive {:partial, ^ref, " I catch"}
    assert_receive {:partial, ^ref, " Ralts"}
    assert_receive {:realtime_done, ^ref, "where do I catch Ralts"}
  end

  test "an error event is reported as a failure with its code" do
    FakeMistralRealtime.serve(:error)
    {relay, ref} = start_relay()
    send(relay, {:audio, "AAA="})

    assert_receive {:realtime_failed, ^ref, {:error_event, 3001}}
  end

  test "a closed socket is reported as a failure" do
    FakeMistralRealtime.serve(:close)
    {relay, ref} = start_relay()
    send(relay, {:audio, "AAA="})

    assert_receive {:realtime_failed, ^ref, {:closed, 1011}}
  end

  test "a frame that is not JSON fails with an atom, never its bytes" do
    FakeMistralRealtime.serve(:garbage)
    {relay, ref} = start_relay()
    send(relay, {:audio, "AAA="})

    assert_receive {:realtime_failed, ^ref, :bad_json}
  end

  test "a refused upgrade is reported with its HTTP status" do
    FakeMistralRealtime.serve(:unauthorized)
    {_relay, ref} = start_relay()

    assert_receive {:realtime_failed, ^ref, {:http, 401}}
  end

  test "a refused connection is reported as a failure" do
    FakeMistralRealtime.point_relay_at("ws://127.0.0.1:1/v1/audio/transcriptions/realtime")
    {_relay, ref} = start_relay()

    assert_receive {:realtime_failed, ^ref, %Mint.TransportError{reason: :econnrefused}}
  end

  test "no API key fails at once without connecting" do
    mistral = Application.fetch_env!(:maya, :mistral)
    Application.put_env(:maya, :mistral, Keyword.put(mistral, :api_key, nil))
    on_exit(fn -> Application.put_env(:maya, :mistral, mistral) end)

    {_relay, ref} = start_relay()
    assert_receive {:realtime_failed, ^ref, :no_api_key}
  end
end
