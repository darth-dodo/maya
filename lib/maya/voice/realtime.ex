defmodule Maya.Voice.Realtime do
  @moduledoc """
  Relay to Voxtral realtime STT over a server side WebSocket (ADR-009,
  https://docs.mistral.ai/studio/audio/speech-to-text/transcribe-in-realtime). One process per
  hold under `Maya.TaskSupervisor`, owning a process-less `Mint.WebSocket` connection
  (https://hexdocs.pm/mint_web_socket/1.0.6/Mint.WebSocket.html), so cutting a turn is killing it.

  The owner sends `{:audio, base64}` and `:end`. Audio waits until `session.created` and
  goes out after the `session.update` settings, on the same socket, so settings come first.
  The owner gets `{:partial, ref, text}` per delta, then `{:realtime_done, ref, text}` or
  `{:realtime_failed, ref, reason}`. Waiting for the final text is the owner's timer.
  """

  alias Maya.Voice.Mistral

  @doc "Starts a relay for one hold. Returns `{pid, monitor_ref}`."
  def start(owner, ref, terms) do
    {:ok, pid} =
      Task.Supervisor.start_child(Maya.TaskSupervisor, fn -> run(owner, ref, terms) end)

    {pid, Process.monitor(pid)}
  end

  @doc "The settings message, sent before any audio."
  def session_update(terms) do
    %{
      type: "session.update",
      session: %{
        audio_format: %{encoding: "pcm_s16le", sample_rate: 16_000},
        language: Mistral.voice(:stt_language),
        context_bias: terms,
        target_streaming_delay_ms: Mistral.voice(:stt_realtime_delay_ms)
      }
    }
  end

  defp run(owner, ref, terms) do
    s = %{owner: owner, ref: ref, terms: terms, queue: [], ready?: false, ws: nil}

    case connect() do
      {:ok, conn, wref} -> loop(Map.merge(s, %{conn: conn, wref: wref}))
      {:error, reason} -> send(owner, {:realtime_failed, ref, reason})
    end
  end

  defp connect do
    key = Application.fetch_env!(:maya, :mistral)[:api_key]
    uri = URI.parse(Mistral.voice(:stt_realtime_url))
    {http, ws} = if uri.scheme == "wss", do: {:https, :wss}, else: {:http, :ws}
    path = uri.path <> "?" <> URI.encode_query(model: Mistral.voice(:stt_realtime_model))

    with true <- (is_binary(key) and key != "") || {:error, :no_api_key},
         {:ok, conn} <- Mint.HTTP.connect(http, uri.host, uri.port, protocols: [:http1]),
         {:ok, conn, wref} <-
           Mint.WebSocket.upgrade(ws, conn, path, [{"authorization", "Bearer " <> key}]) do
      {:ok, conn, wref}
    else
      {:error, reason} -> {:error, reason}
      {:error, _conn, reason} -> {:error, reason}
    end
  end

  defp loop(s) do
    receive do
      {:audio, b64} -> s |> out(%{type: "input_audio.append", audio: b64}) |> loop()
      :end -> s |> out(%{type: "input_audio.end"}) |> loop()
      message -> s |> socket(message) |> loop()
    end
  end

  # Queued until the session exists, so the settings always go first.
  defp out(%{ready?: false} = s, msg), do: %{s | queue: [msg | s.queue]}
  defp out(s, msg), do: frame(s, {:text, Jason.encode!(msg)})

  defp socket(s, message) do
    case Mint.WebSocket.stream(s.conn, message) do
      {:ok, conn, responses} -> Enum.reduce(responses, %{s | conn: conn}, &response/2)
      {:error, _conn, reason, _responses} -> fail(s, reason)
      :unknown -> s
    end
  end

  defp response({:status, _ref, status}, s), do: Map.put(s, :status, status)
  defp response({:headers, _ref, headers}, s), do: Map.put(s, :headers, headers)

  # A first frame in the same packet as the 101 arrives before `:done`: keep it for after.
  defp response({:data, _ref, data}, %{ws: nil} = s),
    do: Map.update(s, :early, data, &(&1 <> data))

  defp response({:done, wref}, %{wref: wref, ws: nil} = s) do
    case Mint.WebSocket.new(s.conn, wref, s.status, s.headers) do
      {:ok, conn, ws} ->
        {early, s} = Map.pop(%{s | conn: conn, ws: ws}, :early)
        if early, do: response({:data, wref, early}, s), else: s

      {:error, _conn, %Mint.WebSocket.UpgradeFailureError{status_code: code}} ->
        fail(s, {:http, code})

      {:error, _conn, reason} ->
        fail(s, reason)
    end
  end

  defp response({:data, _ref, data}, %{ws: ws} = s) do
    case Mint.WebSocket.decode(ws, data) do
      {:ok, ws, frames} -> Enum.reduce(frames, %{s | ws: ws}, &incoming/2)
      {:error, _ws, reason} -> fail(s, reason)
    end
  end

  defp response(_other, s), do: s

  # A bad frame fails with an atom: its bytes may hold transcript text, so they are never logged.
  defp incoming({:text, json}, s) do
    case Jason.decode(json) do
      {:ok, event} -> event(event, s)
      {:error, _} -> fail(s, :bad_json)
    end
  end

  defp incoming({:ping, data}, s), do: frame(s, {:pong, data})
  defp incoming({:close, code, _reason}, s), do: fail(s, {:closed, code})
  defp incoming({:error, reason}, s), do: fail(s, reason)
  defp incoming(_frame, s), do: s

  defp event(%{"type" => "session.created"}, s) do
    queued = Enum.reverse(s.queue)
    s = frame(%{s | ready?: true, queue: []}, {:text, Jason.encode!(session_update(s.terms))})
    Enum.reduce(queued, s, &out(&2, &1))
  end

  defp event(%{"type" => "transcription.text.delta", "text" => text}, s) do
    send(s.owner, {:partial, s.ref, text})
    s
  end

  defp event(%{"type" => "transcription.done", "text" => text}, s) do
    send(s.owner, {:realtime_done, s.ref, String.trim(text)})
    close(s)
  end

  defp event(%{"type" => "error", "error" => error}, s),
    do: fail(s, {:error_event, error["code"]})

  defp event(_other, s), do: s

  defp frame(s, frame) do
    with {:ok, ws, data} <- Mint.WebSocket.encode(s.ws, frame),
         {:ok, conn} <- Mint.WebSocket.stream_request_body(s.conn, s.wref, data) do
      %{s | ws: ws, conn: conn}
    else
      {:error, _ws_or_conn, reason} -> fail(s, reason)
    end
  end

  # Only the reason goes to the owner: never audio, text or the key.
  defp fail(s, reason) do
    send(s.owner, {:realtime_failed, s.ref, reason})
    close(s)
  end

  defp close(s) do
    Mint.HTTP.close(s.conn)
    exit(:normal)
  end
end
