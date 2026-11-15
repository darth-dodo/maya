defmodule Maya.Conversation do
  @moduledoc """
  One guest's Conversation (ARCHITECTURE.md 2, ADR-008), found by `guest_id`. It owns the
  turn in flight: STT, then the agent (with the last 5 turns), then a streamed TTS Answer.
  A held Question streams in as audio chunks (`stream_start/1`, `audio_chunk/2`,
  `stream_end/1`); with realtime on, a relay to Voxtral realtime shows partial text while
  held, and batch STT on the buffered audio gives the final text or takes over when realtime
  fails (ADR-009).
  After 30 idle minutes it stops normally; the next start reloads its turns from Postgres.
  Each step runs in a monitored Task, so a barge-in or a crash cancels it cleanly.
  A heard Question waits `confirm_ms` as a pending Question (`edit/1`, `send_pending/2`,
  `cancel_pending/1`) before the agent; a typed Question (`typed/2`) skips STT and the wait.
  Subscribers on `topic/1` get `{:conversation, event}` with `{:turns, turns}`,
  `{:partial, text}`, `{:pending, text, ms}`, `{:question, text}`, `{:audio, pcm}`,
  `:audio_done` and `:voice_down`.
  """
  # Transient: a crash restarts it, an idle stop does not.
  use GenServer, restart: :transient

  require Logger

  alias Maya.{Agent, GameData}
  alias Maya.Voice.{Mistral, Realtime, STT, TTS, Turn, Vocabulary, Wav}

  @nothing_heard "(nothing heard)"
  @not_heard "I did not catch that."
  @lost "Lost my train of thought, ask again?"
  @idle :timer.minutes(30)
  # A 250 ms chunk is 8,000 bytes; the whole Question keeps the old 1 MB upload cap.
  @max_chunk 16_384
  @max_question 1_000_000
  @max_text 300

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
  def stream_start(id) do
    {:ok, pid} = start_or_find(id)
    GenServer.cast(pid, :stream_start)
  end

  @doc "One base64 chunk of 16 kHz mono 16-bit PCM from the hold."
  def audio_chunk(id, b64), do: GenServer.cast(via(id), {:chunk, b64})

  @doc "The hold ended: the final transcript comes next. A second end is ignored."
  def stream_end(id), do: GenServer.cast(via(id), :stream_end)

  def barge_in(id), do: GenServer.cast(via(id), :barge_in)

  @doc "Tap on the pending Question: stops the countdown. `:error` when nothing is pending."
  def edit(id), do: GenServer.call(via(id), :edit)

  @doc "Sends the edited pending Question. `{:error, :invalid}` unless 1 to 300 characters."
  def send_pending(id, text), do: GenServer.call(via(id), {:send_pending, text})

  @doc "Discards the pending Question: no agent call, no stored turn."
  def cancel_pending(id), do: GenServer.call(via(id), :cancel_pending)

  @doc "A typed Question: cuts the turn in flight and goes to the agent with no STT or countdown."
  def typed(id, text) do
    {:ok, pid} = start_or_find(id)
    GenServer.call(pid, {:typed, text})
  end

  @doc "Typed or edited text, trimmed, if it is 1 to 300 characters."
  def clean_text(text) when is_binary(text) do
    text = String.trim(text)
    if String.length(text) in 1..@max_text, do: {:ok, text}, else: {:error, :invalid}
  end

  def clean_text(_text), do: {:error, :invalid}

  @doc "The screen's timings for the latest turn: `mic_release_ms` and `playback_start_ms`."
  def playback_started(id, timings), do: GenServer.cast(via(id), {:timings, timings})

  @doc "The Question stored when STT heard nothing; the Talk screen shows it as a friendly line."
  def nothing_heard, do: @nothing_heard

  defp via(id), do: {:via, Registry, {Maya.ConversationRegistry, {:conversation, id}}}

  ## Server

  @impl true
  def init(id) do
    idle = Application.get_env(:maya, :conversation_idle_ms, @idle)
    {:ok, %{id: id, idle: idle, turns: Turn.recent(id), current: nil}, idle}
  end

  @impl true
  def handle_call(:turns, _from, state), do: {:reply, all_turns(state), state, state.idle}

  def handle_call(:edit, _from, %{current: %{stage: stage} = c} = state)
      when stage in [:confirm, :editing],
      do: {:reply, :ok, %{state | current: %{c | stage: :editing}}, state.idle}

  def handle_call({:send_pending, text}, _from, %{current: %{stage: stage} = c} = state)
      when stage in [:confirm, :editing] do
    case clean_text(text) do
      {:ok, text} -> {:reply, :ok, ask(state, c, text, c.progress), state.idle}
      error -> {:reply, error, state, state.idle}
    end
  end

  def handle_call(:cancel_pending, _from, %{current: %{stage: stage}} = state)
      when stage in [:confirm, :editing] do
    # A count, never the text.
    Logger.info("pending Question cancelled")
    {:reply, :ok, %{state | current: nil}, state.idle}
  end

  def handle_call({:typed, text}, _from, state) do
    case clean_text(text) do
      {:ok, text} ->
        state = cut(state)
        c = %{ref: make_ref(), task: nil, turn: %Turn{guest_id: state.id, typed: true}}
        {:reply, :ok, ask(state, c, text, nil), state.idle}

      error ->
        {:reply, error, state, state.idle}
    end
  end

  # Nothing pending (the countdown already ended, or a new hold cut it).
  def handle_call(_pending_op, _from, state), do: {:reply, :error, state, state.idle}

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
          turn: %Turn{guest_id: state.id, stt_source: "batch"}
        }
    })
  end

  def handle_cast(:stream_start, state) do
    state = cut(state)
    ref = make_ref()
    progress = GameData.progress(state.id)
    terms = Vocabulary.bias_terms(progress)
    relay = if Mistral.voice(:stt_realtime), do: Realtime.start(self(), ref, terms)

    noreply(%{
      state
      | current: %{
          ref: ref,
          stage: :listening,
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
        {:ok, saved} = Turn.put_timings(last, timings)

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

    broadcast(state, {:audio, pcm})
    noreply(%{state | current: c})
  end

  def handle_info({:partial, ref, text}, %{current: %{ref: ref, stage: stage} = c} = state)
      when stage in [:listening, :realtime_final] do
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

  def handle_info({:confirm, ref}, %{current: %{ref: ref, stage: :confirm} = c} = state),
    do: noreply(ask(state, c, c.pending, c.progress))

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
    progress = GameData.progress(id)
    transcribe(audio, filename, Vocabulary.bias_terms(progress), progress)
  end

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
    c = close_relay(c)
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

  defp finished(:stt, {:ok, "", _progress}, state),
    do: speak(%{state | current: stt_ms(state.current)}, @nothing_heard, @not_heard)

  # The countdown: the Question is pending until `{:confirm, ref}`, an edit or a cut.
  defp finished(:stt, {:ok, question, progress}, %{current: c} = state) do
    c =
      c
      |> stt_ms()
      |> Map.merge(%{
        pending: question,
        progress: progress,
        confirm_from: System.monotonic_time()
      })

    case Mistral.voice(:confirm_ms) do
      0 ->
        ask(state, c, question, progress)

      ms ->
        broadcast(state, {:pending, question, ms})
        Process.send_after(self(), {:confirm, c.ref}, ms)
        %{state | current: %{c | stage: :confirm, task: nil}}
    end
  end

  defp finished(:stt, {:error, reason}, state) do
    warn(:stt, reason)
    broadcast(state, :voice_down)
    %{state | current: nil}
  end

  defp finished(:agent, {:ok, answer}, state),
    do: speak(state, state.current.turn.question, answer)

  # Agent or OpenRouter down, or the round cap: one short spoken line, never silence.
  defp finished(:agent, {:error, reason}, state) do
    warn(:agent, reason)
    speak(state, state.current.turn.question, @lost)
  end

  defp finished(:tts, :ok, state) do
    broadcast(state, :audio_done)
    store(state, state.current.turn)
  end

  defp finished(:tts, {:error, reason}, state) do
    warn(:tts, reason)
    state = store(state, %{state.current.turn | voice_down: true})
    broadcast(state, :voice_down)
    state
  end

  # The agent stage for a heard (confirmed) or typed Question. A typed one reads Progress in
  # the Task, as STT does for a spoken one.
  defp ask(state, c, question, progress) do
    broadcast(state, {:question, question})
    {me, ref, turns, id} = {self(), c.ref, state.turns, state.id}

    task =
      run(fn ->
        opts = [guest_id: id, progress: progress || GameData.progress(id)]

        :telemetry.span([:maya, :voice, :agent], %{conversation: me, ref: ref}, fn ->
          {Agent.answer(question, turns, opts), %{conversation: me, ref: ref}}
        end)
      end)

    turn = %{c.turn | question: question, confirm_ms: confirm_ms(c)}
    %{state | current: Map.merge(c, %{stage: :agent, task: task, turn: turn})}
  end

  defp confirm_ms(%{confirm_from: from}),
    do: System.convert_time_unit(System.monotonic_time() - from, :native, :millisecond)

  defp confirm_ms(_typed), do: nil

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
      :tts -> store(state, %{c.turn | cut: true})
      _hold_stt_or_agent -> %{state | current: nil}
    end
  end

  # Written after the Answer streamed, never on the path to first sound (ADR-006).
  defp store(state, turn) do
    {:ok, saved} = Turn.insert(turn)
    state = %{state | current: nil, turns: Enum.take(state.turns ++ [saved], -20)}
    broadcast(state, {:turns, state.turns})
    state
  end

  defp all_turns(%{current: %{stage: :tts, turn: turn}, turns: turns}), do: turns ++ [turn]
  defp all_turns(%{turns: turns}), do: turns

  # Only the reason (atom, HTTP status, exception message): never transcripts, Answers or keys.
  # A crashed Task arrives here as its exit reason `{exception, stacktrace}`.
  defp warn(stage, {%{__exception__: true} = e, _stack}), do: warn(stage, e)

  defp warn(stage, %{__exception__: true} = e),
    do: Logger.warning("#{stage} failed: #{Exception.message(e)}")

  defp warn(stage, reason), do: Logger.warning("#{stage} failed: #{inspect(reason)}")

  defp run(fun), do: Task.Supervisor.async_nolink(Maya.TaskSupervisor, fun)

  defp broadcast(state, event),
    do: Phoenix.PubSub.broadcast(Maya.PubSub, topic(state.id), {:conversation, event})
end
