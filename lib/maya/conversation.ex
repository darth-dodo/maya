defmodule Maya.Conversation do
  @moduledoc """
  The one Conversation (ARCHITECTURE.md 2). It owns the turn in flight: STT, then the
  agent (with the last 5 turns), then a streamed TTS Answer.
  Each step runs in a monitored Task, so a barge-in or a crash cancels it cleanly.
  Subscribers on `topic/1` get `{:conversation, event}` with `{:turns, turns}`,
  `{:audio, pcm}`, `:audio_done` and `:voice_down`.
  """
  use GenServer

  alias Maya.Agent
  alias Maya.Voice.{STT, Turn, TTS}

  @not_heard "I did not catch that."
  @lost "Lost my train of thought, ask again?"

  ## Client

  def ensure_started(id \\ "main") do
    case DynamicSupervisor.start_child(Maya.ConversationSupervisor, {__MODULE__, id}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  def stop(id) do
    case Registry.lookup(Maya.ConversationRegistry, id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(Maya.ConversationSupervisor, pid)
      [] -> :ok
    end
  end

  def start_link(id), do: GenServer.start_link(__MODULE__, id, name: via(id))

  def topic(id), do: "conversation:#{id}"
  def subscribe(id), do: Phoenix.PubSub.subscribe(Maya.PubSub, topic(id))

  def turns(id), do: GenServer.call(via(id), :turns)
  def question(id, audio, filename), do: GenServer.cast(via(id), {:question, audio, filename})
  def barge_in(id), do: GenServer.cast(via(id), :barge_in)

  @doc "The screen's timings for the latest turn: `mic_release_ms` and `playback_start_ms`."
  def playback_started(id, timings), do: GenServer.cast(via(id), {:timings, timings})

  defp via(id), do: {:via, Registry, {Maya.ConversationRegistry, id}}

  ## Server

  @impl true
  def init(id), do: {:ok, %{id: id, turns: Turn.recent(), current: nil}}

  @impl true
  def handle_call(:turns, _from, state), do: {:reply, all_turns(state), state}

  @impl true
  def handle_cast({:question, audio, filename}, state) do
    state = cut(state)
    me = self()
    ref = make_ref()

    task =
      run(fn ->
        :telemetry.span([:maya, :voice, :stt], %{conversation: me, ref: ref}, fn ->
          {STT.transcribe(audio, filename), %{conversation: me, ref: ref}}
        end)
      end)

    {:noreply, %{state | current: %{ref: ref, task: task, stage: :stt, turn: %Turn{}}}}
  end

  def handle_cast(:barge_in, state), do: {:noreply, cut(state)}

  def handle_cast({:timings, timings}, %{current: %{turn: turn} = c} = state) do
    {:noreply, %{state | current: %{c | turn: struct(turn, timings)}}}
  end

  def handle_cast({:timings, timings}, %{turns: turns} = state) do
    case List.last(turns) do
      %Turn{id: id} = last when is_integer(id) ->
        {:ok, saved} = Turn.put_timings(last, timings)

        {:noreply,
         %{state | turns: List.replace_at(turns, -1, %{saved | voice_down: last.voice_down})}}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({ref, result}, %{current: %{task: %Task{ref: ref}}} = state) do
    Process.demonitor(ref, [:flush])
    {:noreply, finished(state.current.stage, result, state)}
  end

  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{current: %{task: %Task{ref: ref}}} = state
      ) do
    {:noreply, finished(state.current.stage, {:error, reason}, state)}
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
    {:noreply, %{state | current: c}}
  end

  def handle_info({:stage_ms, ref, stage, ms}, %{current: %{ref: ref, turn: turn} = c} = state) do
    {:noreply, %{state | current: %{c | turn: Map.put(turn, stage, ms)}}}
  end

  # Late chunks, timings and task results of a cut or finished turn.
  def handle_info(_stale, state), do: {:noreply, state}

  ## Turn steps

  defp finished(:stt, {:ok, ""}, state), do: speak(state, "(nothing heard)", @not_heard)

  defp finished(:stt, {:ok, question}, %{current: c} = state) do
    me = self()
    ref = c.ref
    turns = state.turns

    task =
      run(fn ->
        :telemetry.span([:maya, :voice, :agent], %{conversation: me, ref: ref}, fn ->
          {Agent.answer(question, turns), %{conversation: me, ref: ref}}
        end)
      end)

    %{state | current: %{c | stage: :agent, task: task, turn: %{c.turn | question: question}}}
  end

  defp finished(:stt, {:error, _reason}, state) do
    broadcast(state, :voice_down)
    %{state | current: nil}
  end

  defp finished(:agent, {:ok, answer}, state),
    do: speak(state, state.current.turn.question, answer)

  # Agent or OpenRouter down, or the round cap: one short spoken line, never silence.
  defp finished(:agent, {:error, _reason}, state),
    do: speak(state, state.current.turn.question, @lost)

  defp finished(:tts, :ok, state) do
    broadcast(state, :audio_done)
    store(state, state.current.turn)
  end

  defp finished(:tts, {:error, _reason}, state) do
    state = store(state, %{state.current.turn | voice_down: true})
    broadcast(state, :voice_down)
    state
  end

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
    Process.demonitor(c.task.ref, [:flush])
    Task.Supervisor.terminate_child(Maya.TaskSupervisor, c.task.pid)

    case c.stage do
      :tts -> store(state, %{c.turn | cut: true})
      _stt_or_agent -> %{state | current: nil}
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

  defp run(fun), do: Task.Supervisor.async_nolink(Maya.TaskSupervisor, fun)

  defp broadcast(state, event),
    do: Phoenix.PubSub.broadcast(Maya.PubSub, topic(state.id), {:conversation, event})
end
