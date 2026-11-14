defmodule MayaWeb.TalkLive do
  @moduledoc """
  The Talk screen at `/` (ARCHITECTURE.md 1). It only draws: the Question arrives as a
  LiveView upload from the TalkHook, the Conversation does the work, and Answer audio
  goes back to the hook as pushed PCM events (ADR-005).
  """
  use MayaWeb, :live_view

  alias Maya.Conversation
  alias Maya.Voice.Turn

  @conversation "main"

  # Before the first gym only; each fact's source: openspec/changes/archive/*-home-poke-facts/design.md
  # The CSS rotation in app.css times 12 items: update both together.
  @poke_facts [
    "Mudkip is a pure Water type, and Maya is not biased at all.",
    "Treecko is a pure Grass type.",
    "Torchic is a pure Fire type.",
    "All three Hoenn starters evolve at level 16 and again at level 36.",
    "Poochyena is a Dark type found on every route from 101 to 104 and in Petalburg Woods.",
    "Zigzagoon is a Normal type you can meet on Routes 101, 102 and 103.",
    "Wurmple evolves at level 7 into either Silcoon or Cascoon.",
    "Ralts hides in the Route 102 grass with just a 4 percent encounter rate.",
    "Seedot is the rarest find on Route 102: a 1 percent encounter.",
    "Lotad is a Water and Grass type living in the Route 102 grass.",
    "Wingull is a Water and Flying type that turns up on Routes 103 and 104.",
    "Slakoth naps in Petalburg Woods and shows up in 5 percent of encounters there."
  ]

  @timings %{"mic_release_ms" => :mic_release_ms, "playback_start_ms" => :playback_start_ms}

  def poke_facts, do: @poke_facts

  @impl true
  def mount(_params, _session, socket) do
    turns =
      if connected?(socket) do
        {:ok, _} = Conversation.ensure_started(@conversation)
        Conversation.subscribe(@conversation)
        Conversation.turns(@conversation)
      else
        Turn.recent()
      end

    {:ok,
     socket
     |> assign(
       turns: turns,
       voice_down: false,
       sample_rate: Application.fetch_env!(:maya, :voice)[:tts_sample_rate]
     )
     |> allow_upload(:question,
       accept: ~w(.wav .webm .mp4),
       auto_upload: true,
       chunk_size: 256_000,
       max_file_size: 1_000_000,
       max_entries: 1,
       progress: &handle_progress/3
     )}
  end

  defp handle_progress(:question, %{done?: true} = entry, socket) do
    audio = consume_uploaded_entry(socket, entry, fn %{path: path} -> {:ok, File.read!(path)} end)
    Conversation.question(@conversation, audio, "question" <> Path.extname(entry.client_name))
    {:noreply, socket |> assign(voice_down: false) |> push_event("heard", %{})}
  end

  defp handle_progress(:question, _entry, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("barge_in", _params, socket) do
    Conversation.barge_in(@conversation)
    {:noreply, socket}
  end

  # Client numbers are untrusted: keep only the two known, non-negative integers.
  def handle_event("playback_started", params, socket) do
    timings =
      for {key, field} <- @timings,
          {:ok, ms} <- [Map.fetch(params, key)],
          is_integer(ms) and ms >= 0,
          into: %{},
          do: {field, ms}

    Conversation.playback_started(@conversation, timings)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:conversation, {:turns, turns}}, socket),
    do: {:noreply, assign(socket, turns: turns)}

  def handle_info({:conversation, {:audio, pcm}}, socket),
    do: {:noreply, push_event(socket, "audio", %{pcm: Base.encode64(pcm)})}

  def handle_info({:conversation, :audio_done}, socket),
    do: {:noreply, push_event(socket, "audio_done", %{})}

  # A failed TTS flags its turn; only a failed STT (no turn) needs the note on its own.
  def handle_info({:conversation, :voice_down}, socket) do
    on_turn? = match?(%Turn{voice_down: true}, List.last(socket.assigns.turns))
    {:noreply, socket |> assign(voice_down: not on_turn?) |> push_event("voice_down", %{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="maya-hero" class="maya-hero rounded-2xl text-center" data-backdrop="tide">
        <div class="maya-hero-panel">
          <div id="pokeball" class="pokeball pokeball-emerald mx-auto" aria-hidden="true">
            <div class="pokeball-button"></div>
          </div>
          <h1 id="maya-heading" class="mt-3 text-2xl font-semibold">Maya</h1>
          <p id="tagline" class="mt-2 text-sm">
            Maps, Answers, Yaps, Advice. Your spoiler-free Pokemon Emerald companion.
          </p>
          <p id="mudkip-hype" class="mt-2 text-sm font-semibold">
            Mudkip hype: 100. Best starter, no debate.
          </p>
        </div>
      </section>

      <ol id="conversation" class="space-y-3" aria-live="polite" aria-label="Conversation">
        <li :for={turn <- @turns} class="turn rounded-2xl bg-base-200 p-4">
          <p class="question">{turn.question}</p>
          <p class="answer mt-1">{turn.answer}</p>
          <p :if={turn.cut} class="cut mt-1 text-sm opacity-70">cut short</p>
          <p :if={turn.voice_down} class="voice-down mt-1 text-sm text-warning">voice is down</p>
        </li>
      </ol>

      <p :if={@voice_down} id="voice-down" class="voice-down text-sm text-warning">voice is down</p>

      <form id="question-form" phx-change="validate" phx-submit="validate" class="hidden">
        <.live_file_input upload={@uploads.question} />
      </form>

      <button
        id="talk-button"
        type="button"
        class="talk-button"
        phx-hook="TalkHook"
        phx-update="ignore"
        data-state="idle"
        data-sample-rate={@sample_rate}
      >
        Hold to talk
      </button>

      <div :if={@turns == []}>
        <section class="mt-8">
          <h2 class="text-lg font-semibold">Poke facts</h2>
          <ul id="poke-facts" class="poke-facts mt-4 rounded-2xl" aria-label="Poke facts">
            <li :for={fact <- poke_facts()} class="poke-fact">{fact}</li>
          </ul>
        </section>

        <section class="mt-8">
          <h2 class="text-lg font-semibold">Badge case</h2>
          <ul id="badge-case" class="mt-4 grid grid-cols-4 gap-3 sm:grid-cols-8">
            <li
              :for={n <- 1..8}
              class="badge-slot flex aspect-square items-center justify-center rounded-full border-2 border-dashed border-base-content/30 text-sm opacity-70"
              data-earned="false"
              aria-label={"Badge #{n} of 8"}
            >
              {n}
            </li>
          </ul>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
