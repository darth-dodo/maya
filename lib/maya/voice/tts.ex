defmodule Maya.Voice.TTS do
  @moduledoc """
  Voxtral text to speech, streamed: `POST /v1/audio/speech` with `stream: true` and
  `response_format: "pcm"`. Server-sent `speech.audio.delta` events carry base64
  `audio_data`; `speech.audio.done` ends the stream
  (https://docs.mistral.ai/studio/audio/text-to-speech/stream-speech).
  """

  alias Maya.Voice.{Mistral, SSE}

  @error_bytes 500

  @doc "Streams `text` as PCM, calling `on_chunk` with each decoded chunk in the calling process."
  @spec stream(String.t(), (binary() -> any())) :: :ok | {:error, term()}
  def stream(text, on_chunk) do
    with {:ok, req} <- Mistral.new(:tts_timeout_ms) do
      req
      |> Req.post(
        url: "/v1/audio/speech",
        json: %{
          model: Mistral.voice(:tts_model),
          voice_id: Mistral.voice(:tts_voice),
          input: text,
          response_format: "pcm",
          stream: true
        },
        into: &relay(&1, &2, on_chunk)
      )
      |> case do
        {:ok, %{status: 200}} -> :ok
        {:ok, %{status: s} = resp} -> {:error, {:http, s, error_body(resp, text)}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp relay({:data, data}, {req, %{status: 200} = resp}, on_chunk) do
    {events, rest} = SSE.parse((Req.Response.get_private(resp, :sse) || "") <> data)

    for {"speech.audio.delta", %{"audio_data" => b64}} <- events,
        do: on_chunk.(Base.decode64!(b64))

    {:cont, {req, Req.Response.put_private(resp, :sse, rest)}}
  end

  # An error body is not audio: its first @error_bytes are kept for the log, since the status
  # alone does not say why (#96, cantastorie 7869d98). It holds the provider's message, never
  # audio, the Answer or the key.
  defp relay({:data, data}, {req, resp}, _on_chunk) do
    kept = Req.Response.get_private(resp, :error, "") <> data
    kept = binary_part(kept, 0, min(byte_size(kept), @error_bytes))
    {:cont, {req, Req.Response.put_private(resp, :error, kept)}}
  end

  # A validation error can echo the input: the Answer never reaches the log.
  defp error_body(resp, text),
    do: resp |> Req.Response.get_private(:error, "") |> String.replace(text, "[input]")
end
