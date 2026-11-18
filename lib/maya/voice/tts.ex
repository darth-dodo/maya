defmodule Maya.Voice.TTS do
  @moduledoc """
  Voxtral text to speech, streamed: `POST /v1/audio/speech` with `stream: true` and
  `response_format: "pcm"`. Server-sent `speech.audio.delta` events carry base64
  `audio_data`; `speech.audio.done` ends the stream
  (https://docs.mistral.ai/studio/audio/text-to-speech/stream-speech).
  """

  alias Maya.Voice.{Mistral, SSE}

  # The logged error body is cut to @error_bytes only after the Answer is redacted, so up to
  # @error_buffer bytes are read first (an Answer is about 250 characters).
  @error_bytes 500
  @error_buffer 8_192

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
        {:ok, %{status: status} = resp} -> {:error, {:http, status, error_body(resp, text)}}
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

  # An error body is not audio: it is kept for the log, since the status alone does not say
  # why (#96, cantastorie 7869d98).
  defp relay({:data, data}, {req, resp}, _on_chunk) do
    {:cont,
     {req, Req.Response.put_private(resp, :error, cut(get_error(resp) <> data, @error_buffer))}}
  end

  # A validation error can echo the input, raw or JSON escaped: both are redacted before the
  # cut, so no part of the Answer reaches the log. The cut never leaves half a character.
  defp error_body(resp, text) do
    json = Jason.encode!(text)
    echoes = Enum.reject([text, binary_part(json, 1, byte_size(json) - 2)], &(&1 == ""))

    resp
    |> get_error()
    |> String.replace(echoes, "[input]")
    |> cut(@error_bytes)
    |> String.replace_invalid("")
  end

  defp get_error(resp), do: Req.Response.get_private(resp, :error, "")

  defp cut(bin, max), do: binary_part(bin, 0, min(byte_size(bin), max))
end
