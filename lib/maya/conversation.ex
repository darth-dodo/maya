defmodule Maya.Conversation do
  @moduledoc """
  One guest's Conversation (ARCHITECTURE.md 2, ADR-008), found by `guest_id`. It owns the
  turn in flight: STT, then the agent (with the last 25 turns), then a streamed TTS Answer.
  A held Question streams in as audio chunks (`stream_start/2`, `audio_chunk/2`,
  `stream_end/1`); with realtime on, a relay to Voxtral realtime shows partial text while
  held, and batch STT on the buffered audio gives the final text or takes over when realtime
  fails (ADR-009).
  After 30 idle minutes it stops normally; the next start reloads its turns from Postgres.
  Each step runs in a monitored Task, so a barge-in or a crash cancels it cleanly.
  Subscribers on `topic/1` get `{:conversation, event}` with `{:turns, turns}`,
  `{:partial, text}`, `{:question, text}`, `{:audio, turn_id, pcm}`, `{:audio_done, turn_id}`
  and `:voice_down`. `turn_id` is the id the hold sent with `stream_start/2` (nil for an upload),
  so the screen can drop a cut turn's late audio (#96).
  """
  # Transient: a crash restarts it, an idle stop does not.
  use GenServer, restart: :transient

  require Logger

  alias Maya.{Agent, GameData}
  alias Maya.Voice.{Mistral, Realtime, STT, TTS, Turn, Vocabulary, Wav}

  @nothing_heard "(nothing heard)"
  @not_heard "I did not catch that."
  @lost "Lost my train of thought, ask again?"
  @notes_down Agent.notes_down()
  @db_errors Maya.Repo.outage_errors()
  @idle :timer.minutes(30)
  # A 250 ms chunk is 8,000 bytes; the whole Question keeps the old 1 MB upload cap.
  @max_chunk 16_384
  @max_question 1_000_000

  ## Client

  def start_or_find(id) when is_binary(id) do
    case DynamicSupervisor.start_child(Maya.ConversationSupervisor, {__MODULE__, id}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  def stop(id) do
    case Registry.lookup(Maya.ConversationRegistry, {:conversation, id}) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(Maya.ConversationSupervisor, pid)
      [] -> :ok
    end
  end

  def start_link(id), do: GenServer.start_link(__MODULE__, id, name: via(id))

  def topic(id), do: "conversation:#{id}"
  def subscribe(id), do: Phoenix.PubSub.subscribe(Maya.PubSub, topic(id))

  def turns(id), do: GenServer.call(via(id), :turns)
  # Starts the Conversation first, so a Question after an idle stop is not dropped.
  def question(id, audio, filename) do
    {:ok, pid} = start_or_find(id)
    GenServer.cast(pid, {:question, audio, filename})
  end

  @doc "A hold began: cuts the turn in flight and opens the realtime session when it is on."
  def stream_start(id, turn_id \\ nil) do
    {:ok, pid} = start_or_find(id)
    GenServer.cast(pid, {:stream_start, turn_id})
  end

  @doc "One base64 chunk of 16 kHz mono 16-bit PCM from the hold."
  def audio_chunk(id, b64), do: GenServer.cast(via(id), {:chunk, b64})

  @doc "The hold ended: the final transcript comes next. A second end is ignored."
  def stream_end(id), do: GenServer.cast(via(id), :stream_end)

  def barge_in(id), do: GenServer.cast(via(id), :barge_in)

  @doc "The screen's timings for the latest turn: `mic_release_ms` and `playback_start_ms`."
  def playback_started(id, timings), do: GenServer.cast(via(id), {:timings, timings})

  @doc "The Question stored when STT heard nothing; the Talk screen shows it as a friendly line."
  def nothing_heard, do: @nothing_heard

  defp via(id), do: {:via, Registry, {Maya.ConversationRegistry, {:conversation, id}}}

  ## Server

  @impl true
  def init(id) do
    idle = Application.get_env(:maya, :conversation_idle_ms, @idle)
    turns = db(:turns, fn -> Turn.recent(id) end, [])
    {:ok, %{id: id, idle: idle, turns: turns, current: nil}, idle}
  end

  @impl true
  def handle_call(:turns, _from, state), do: {:reply, all_turns(state), state, state.idle}

  @impl true
  def handle_cast({:question, audio, filename}, state) do
    state = cut(state)
    me = self()
    ref = make_ref()
    id = state.id

    task =
      run(fn ->
        :telemetry.span([:maya, :voice, :stt], %{conversation: me, ref: ref}, fn ->
          {transcribe(id, audio, filename), %{conversation: me, ref: ref}}
        end)
      end)

    noreply(%{
      state
      | current: %{
          ref: ref,
          task: task,
          stage: :stt,
          turn_id: nil,
          turn: %Turn{guest_id: state.id, stt_source: "batch"}
        }
    })
  end

  def handle_cast({:stream_start, turn_id}, state) do
    state = cut(state)
    ref = make_ref()
    progress = read_progress(state.id)
    terms = terms(progress)
    relay = if Mistral.voice(:stt_realtime), do: Realtime.start(self(), ref, terms)

    noreply(%{
      state
      | current: %{
          ref: ref,
          stage: :listening,
          turn_id: turn_id,
          relay: relay,
          audio: [],
          bytes: 0,
          partial: "",
          task: nil,
          progress: progress,
          terms: terms,
          turn: %Turn{guest_id: state.id}
        }
    })
  end

  def handle_cast({:chunk, b64}, %{current: %{stage: :listening} = c} = state) do
    case chunk(b64, c.bytes) do
      {:ok, pcm} ->
        with {pid, _mon} <- c.relay, do: send(pid, {:audio, b64})

        noreply(%{
          state
          | current: %{c | audio: [c.audio | pcm], bytes: c.bytes + byte_size(pcm)}
        })

      {:error, reason, size} ->
        # Only the reason and size: never audio.
        Logger.warning("audio chunk dropped: #{inspect(reason)}#{size && ", #{size} bytes"}")
        noreply(state)
    end
  end

  def handle_cast(:stream_end, %{current: %{stage: :listening} = c} = state) do
    c = Map.put(c, :stt_from, System.monotonic_time())

    cond do
      c.bytes == 0 ->
        noreply(speak(%{state | current: close_relay(c)}, @nothing_heard, @not_heard))

      c.relay && Mistral.voice(:stt_final) == :realtime ->
        {pid, _mon} = c.relay
        send(pid, :end)
        Process.send_after(self(), {:done_timeout, c.ref}, Mistral.voice(:stt_realtime_done_ms))
        noreply(%{state | current: %{c | stage: :realtime_final}})

      true ->
        # Preview only: the relay stays open while batch runs, so the words Voxtral sends after
        # `input_audio.end` still reach the preview (#110).
        with {pid, _mon} <- c.relay, do: send(pid, :end)
        noreply(batch(state, c))
    end
  end

  # Chunks and ends outside a hold: late, or a second end for the same hold.
  def handle_cast({:chunk, _b64}, state), do: noreply(state)
  def handle_cast(:stream_end, state), do: noreply(state)

  def handle_cast(:barge_in, state), do: noreply(cut(state))

  def handle_cast({:timings, timings}, %{current: %{turn: turn} = c} = state) do
    noreply(%{state | current: %{c | turn: struct(turn, timings)}})
  end

  def handle_cast({:timings, timings}, %{turns: turns} = state) do
    case List.last(turns) do
      %Turn{id: id} = last when is_integer(id) ->
        saved = db(:timings, fn -> Turn.put_timings(last, timings) end, struct(last, timings))

        noreply(%{
          state
          | turns: List.replace_at(turns, -1, %{saved | voice_down: last.voice_down})
        })

      _ ->
        noreply(state)
    end
  end

  @impl true
  def handle_info({ref, result}, %{current: %{task: %Task{ref: ref}}} = state) do
    Process.demonitor(ref, [:flush])
    noreply(finished(state.current.stage, result, state))
  end

  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{current: %{task: %Task{ref: ref}}} = state
      ) do
    noreply(finished(state.current.stage, {:error, reason}, state))
  end

  def handle_info({:tts_chunk, ref, pcm}, %{current: %{ref: ref, turn: turn} = c} = state) do
    c =
      if turn.tts_first_byte_ms do
        c
      else
        # Recorded here, not via Maya.Voice.Timing, so it lands before the stream can end.
        duration = System.monotonic_time() - c.tts_started
        :telemetry.execute([:maya, :voice, :tts_first_byte, :stop], %{duration: duration}, %{})
        ms = System.convert_time_unit(duration, :native, :millisecond)
        %{c | turn: %{turn | tts_first_byte_ms: ms}}
      end

    broadcast(state, {:audio, c.turn_id, pcm})
    noreply(%{state | current: c})
  end

  def handle_info({:partial, ref, text}, %{current: %{ref: ref, stage: stage} = c} = state)
      when stage in [:listening, :realtime_final, :stt] do
    c = %{c | partial: c.partial <> text}
    broadcast(state, {:partial, c.partial})
    noreply(%{state | current: c})
  end

  def handle_info(
        {:realtime_done, ref, text},
        %{current: %{ref: ref, stage: :realtime_final} = c} = state
      ) do
    c = %{c | relay: nil, turn: %{c.turn | stt_source: "realtime"}}

    noreply(
      finished(:stt, {:ok, Vocabulary.correct(text, c.terms), c.progress}, %{state | current: c})
    )
  end

  # Preview only: batch gives the final text, the relay has closed itself.
  def handle_info({:realtime_done, ref, _text}, %{current: %{ref: ref, stage: :stt} = c} = state),
    do: noreply(%{state | current: %{c | relay: nil}})

  def handle_info(
        {:realtime_failed, ref, reason},
        %{current: %{ref: ref, stage: stage} = c} = state
      )
      when stage in [:listening, :realtime_final],
      do: noreply(realtime_failed(state, c, reason))

  def handle_info(
        {:done_timeout, ref},
        %{current: %{ref: ref, stage: :realtime_final} = c} = state
      ),
      do: noreply(realtime_failed(state, close_relay(c), :done_timeout))

  def handle_info(
        {:DOWN, mon, :process, _pid, reason},
        %{current: %{relay: {_relay, mon}} = c} = state
      )
      when reason != :normal,
      do: noreply(realtime_failed(state, %{c | relay: nil}, {:exit, crash_kind(reason)}))

  def handle_info({:stage_ms, ref, stage, ms}, %{current: %{ref: ref, turn: turn} = c} = state) do
    noreply(%{state | current: %{c | turn: Map.put(turn, stage, ms)}})
  end

  # No message for the idle time: stop; the guest's turns are already in Postgres.
  def handle_info(:timeout, state), do: {:stop, :normal, state}

  # Late chunks, timings and task results of a cut or finished turn.
  def handle_info(_stale, state), do: noreply(state)

  # Every reply re-arms the idle timeout (GenServer timeout, reset by any message).
  defp noreply(state), do: {:noreply, state, state.idle}

  ## Turn steps

  # The turn's one Progress read: it biases STT toward the Team and horizon and goes on to the agent.
  defp transcribe(id, audio, filename) do
    progress = read_progress(id)
    transcribe(audio, filename, terms(progress), progress)
  end

  # Postgres down or paused (#82): STT still runs, unbiased, and Maya says her notes are offline.
  defp read_progress(id), do: db(:progress, fn -> GameData.progress(id) end, :notes_down)

  defp terms(:notes_down), do: []
  defp terms(progress), do: Vocabulary.bias_terms(progress)

  defp transcribe(audio, filename, terms, progress) do
    with {:ok, text} <- STT.transcribe(audio, filename, terms),
         do: {:ok, Vocabulary.correct(text, terms), progress}
  end

  defp chunk(b64, bytes) do
    case Base.decode64(b64) do
      {:ok, pcm} when byte_size(pcm) > @max_chunk ->
        {:error, :too_big, byte_size(pcm)}

      {:ok, pcm} when bytes + byte_size(pcm) > @max_question ->
        {:error, :over_question_cap, byte_size(pcm)}

      {:ok, pcm} ->
        {:ok, pcm}

      :error ->
        {:error, :bad_base64, nil}
    end
  end

  # Batch STT on the hold's buffered audio: the final source, or the fallback.
  defp batch(state, c) do
    wav = Wav.wrap(IO.iodata_to_binary(c.audio), 16_000)
    {terms, progress, me, ref} = {c.terms, c.progress, self(), c.ref}

    task =
      run(fn ->
        :telemetry.span([:maya, :voice, :stt], %{conversation: me, ref: ref}, fn ->
          {transcribe(wav, "question.wav", terms, progress), %{conversation: me, ref: ref}}
        end)
      end)

    turn = %{c.turn | stt_source: "batch"}
    %{state | current: %{c | stage: :stt, task: task, audio: [], turn: turn}}
  end

  # The reason only, as for every stage. While held, batch waits for the end of the hold.
  defp realtime_failed(state, c, reason) do
    warn(:stt_realtime, reason)
    c = %{c | relay: nil}

    case c.stage do
      :realtime_final -> batch(state, c)
      _listening -> %{state | current: c}
    end
  end

  defp close_relay(%{relay: {pid, mon}} = c) do
    Process.demonitor(mon, [:flush])
    Task.Supervisor.terminate_child(Maya.TaskSupervisor, pid)
    %{c | relay: nil}
  end

  defp close_relay(c), do: c

  # A crashed relay's exit carries its state (queued audio) in the stacktrace: log the kind only.
  defp crash_kind({%{__exception__: true, __struct__: kind}, _stack}), do: kind
  defp crash_kind(reason) when is_atom(reason), do: reason
  defp crash_kind(_reason), do: :crashed

  # A streamed Question: release to final transcript (spec, Realtime latency). It replaces the
  # batch Task's own span, which misses any wait for realtime before the fallback.
  defp stt_ms(%{stt_from: from, turn: turn} = c) do
    ms = System.convert_time_unit(System.monotonic_time() - from, :native, :millisecond)
    %{c | turn: %{turn | stt_ms: ms}}
  end

  defp stt_ms(c), do: c

  # Batch is final: a preview relay still open stops here, so no late partial follows it.
  defp finished(:stt, result, %{current: %{relay: {_pid, _mon}} = c} = state),
    do: finished(:stt, result, %{state | current: close_relay(c)})

  defp finished(:stt, {:ok, "", _progress}, state),
    do: speak(%{state | current: stt_ms(state.current)}, @nothing_heard, @not_heard)

  # A database problem, not a voice one: the honest line is spoken, never "voice is down" (#82).
  defp finished(:stt, {:ok, question, :notes_down}, state) do
    broadcast(state, {:question, question})
    speak(%{state | current: stt_ms(state.current)}, question, @notes_down)
  end

  defp finished(:stt, {:ok, question, progress}, %{current: c} = state) do
    c = stt_ms(c)
    broadcast(state, {:question, question})
    me = self()
    ref = c.ref
    turns = state.turns
    opts = [guest_id: state.id, progress: progress]

    task =
      run(fn ->
        :telemetry.span([:maya, :voice, :agent], %{conversation: me, ref: ref}, fn ->
          {Agent.answer(question, turns, opts), %{conversation: me, ref: ref}}
        end)
      end)

    %{state | current: %{c | stage: :agent, task: task, turn: %{c.turn | question: question}}}
  end

  defp finished(:stt, {:error, reason}, state) do
    warn(:stt, reason)
    broadcast(state, :voice_down)
    %{state | current: nil}
  end

  defp finished(:agent, {:ok, answer}, state) do
    state = speak(state, state.current.turn.question, answer)
    progress_news(state)
    state
  end

  # Agent or OpenRouter down, or the round cap: one short spoken line, never silence.
  defp finished(:agent, {:error, reason}, state) do
    warn(:agent, reason)
    state = speak(state, state.current.turn.question, @lost)
    progress_news(state)
    state
  end

  defp finished(:tts, :ok, state) do
    broadcast(state, {:audio_done, state.current.turn_id})
    store(state, state.current.turn)
  end

  defp finished(:tts, {:error, reason}, state) do
    warn(:tts, reason)
    state = store(state, %{state.current.turn | voice_down: true})
    broadcast(state, :voice_down)
    state
  end

  # The agent may have logged or undone Events, so the screen redraws its card (#89). Read once TTS
  # is already streaming, off the path to first sound; a failed read keeps the turn going.
  defp progress_news(state),
    do:
      db(
        :progress_news,
        fn -> broadcast(state, {:progress, GameData.progress(state.id)}) end,
        :ok
      )

  # Starts streaming the Answer; the turn shows on screen from here.
  defp speak(%{current: c} = state, question, answer) do
    me = self()
    ref = c.ref

    state = %{
      state
      | current:
          %{
            c
            | stage: :tts,
              turn: %{c.turn | question: question, answer: answer},
              task: run(fn -> TTS.stream(answer, &send(me, {:tts_chunk, ref, &1})) end)
          }
          |> Map.put(:tts_started, System.monotonic_time())
    }

    broadcast(state, {:turns, all_turns(state)})
    state
  end

  # Cancels the turn in flight. A spoken Answer is kept as text and marked cut.
  defp cut(%{current: nil} = state), do: state

  defp cut(%{current: c} = state) do
    c = close_relay(c)

    with %Task{} = task <- c.task do
      Process.demonitor(task.ref, [:flush])
      Task.Supervisor.terminate_child(Maya.TaskSupervisor, task.pid)
    end

    case c.stage do
      :tts ->
        store(state, %{c.turn | cut: true})

      # A cut agent may have logged Events already.
      :agent ->
        progress_news(state)
        %{state | current: nil}

      _hold_or_stt ->
        %{state | current: nil}
    end
  end

  # Written after the Answer streamed, never on the path to first sound (ADR-006). With Postgres
  # down the turn stays in memory only: Maya already answered (#82).
  defp store(state, turn) do
    saved = db(:store, fn -> Turn.insert(turn) end, turn)

    state = %{state | current: nil, turns: Enum.take(state.turns ++ [saved], -Turn.window())}
    broadcast(state, {:turns, state.turns})
    state
  end

  defp all_turns(%{current: %{stage: :tts, turn: turn}, turns: turns}),
    do: Enum.take(turns ++ [turn], -Turn.window())

  defp all_turns(%{turns: turns}), do: turns

  # Only the reason (atom, HTTP status, exception message): never transcripts, Answers or keys.
  # A crashed Task arrives here as its exit reason `{exception, stacktrace}`.
  defp warn(stage, {%{__exception__: true} = e, _stack}), do: warn(stage, e)

  defp warn(stage, %{__exception__: true} = e),
    do: Logger.warning("#{stage} failed: #{Exception.message(e)}")

  defp warn(stage, reason), do: Logger.warning("#{stage} failed: #{inspect(reason)}")

  # A failed database call logs its kind and returns `fallback`, so the turn goes on (#82). Only
  # database errors are caught (OwnershipError is how tests take the pool away); a code bug crashes.
  defp db(stage, fun, fallback) do
    case fun.() do
      {:ok, value} ->
        value

      {:error, _changeset} ->
        Logger.warning("#{stage} failed: :invalid")
        fallback

      value ->
        value
    end
  rescue
    e in @db_errors ->
      Logger.warning("#{stage} failed: #{db_reason(e)}")
      fallback
  end

  # Never a query error's message: Postgres can quote the failing row (the turn's text).
  defp db_reason(%DBConnection.ConnectionError{} = e), do: Exception.message(e)
  defp db_reason(%Postgrex.Error{postgres: %{code: code}}), do: inspect(code)
  defp db_reason(e), do: inspect(e.__struct__)

  defp run(fun), do: Task.Supervisor.async_nolink(Maya.TaskSupervisor, fun)

  defp broadcast(state, event),
    do: Phoenix.PubSub.broadcast(Maya.PubSub, topic(state.id), {:conversation, event})
end
