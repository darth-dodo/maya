defmodule Maya.Voice.STT do
  @moduledoc """
  Voxtral speech to text: `POST /v1/audio/transcriptions`, multipart `model`, `language`,
  one `context_bias` field per term and `file`, transcript in `text`
  (https://docs.mistral.ai/studio/audio/speech-to-text/transcribe-files). Bias terms share
  the model's 65,536 token window with the audio; over it the request fails with a 400.
  """

  alias Maya.Voice.Mistral

  @spec transcribe(binary(), String.t(), [String.t()]) :: {:ok, String.t()} | {:error, term()}
  def transcribe(audio, filename, bias_terms \\ []) do
    with {:ok, req} <- Mistral.new(:stt_timeout_ms) do
      req
      |> Req.post(
        url: "/v1/audio/transcriptions",
        form_multipart:
          [model: Mistral.voice(:stt_model), language: Mistral.voice(:stt_language)] ++
            Enum.map(bias_terms, &{:context_bias, &1}) ++
            [file: {audio, filename: filename}]
      )
      |> case do
        {:ok, %{status: 200, body: %{"text" => text}}} -> {:ok, String.trim(text)}
        {:ok, %{status: status}} -> {:error, {:http, status}}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
