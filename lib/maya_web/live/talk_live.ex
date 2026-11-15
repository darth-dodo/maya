defmodule MayaWeb.TalkLive do
  @moduledoc """
  The Talk screen at `/` (ARCHITECTURE.md 1). It only draws: the Question arrives as a
  LiveView upload from the TalkHook, the Conversation does the work, and Answer audio
  goes back to the hook as pushed PCM events (ADR-005). It talks to the Conversation of the
  guest in the session (ADR-008).
  """
  use MayaWeb, :live_view

  alias Maya.Conversation
  alias Maya.GameData
  alias Maya.Horizon
  alias Maya.Voice.Turn

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

  # The TalkHook's states, mirrored on the screen root so CSS draws each moment.
  @talk_states ~w(idle recording uploading waiting speaking)

  def poke_facts, do: @poke_facts

  @impl true
  def mount(_params, %{"guest_id" => guest_id}, socket) do
    turns =
      if connected?(socket) do
        {:ok, _} = Conversation.start_or_find(guest_id)
        Conversation.subscribe(guest_id)
        Conversation.turns(guest_id)
      else
        Turn.recent(guest_id)
      end

    {:ok,
     socket
     |> assign(
       guest_id: guest_id,
       turns: turns,
       card: trainer_card(GameData.progress(guest_id)),
       talk_state: "idle",
       voice_down: false,
       confirm_fresh: false,
       fresh_form: to_form(%{}),
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

  # A tab opened before guests reconnects with a session that has none: reload the page,
  # so the browser pipeline gives it a guest.
  def mount(_params, _session, socket), do: {:ok, redirect(socket, to: ~p"/")}

  # Read once on mount: Progress only changes through Start fresh, which leaves the page.
  defp trainer_card(progress) do
    next = Horizon.next_gym(progress)

    %{
      location: progress.location,
      next_gym: next && next.leader,
      gym_type: next && gym_type(next),
      team:
        for(
          %{"species" => s, "level" => l} <- progress.team,
          do: %{name: String.capitalize(s), level: l, types: types(s)}
        ),
      badges: progress.badges,
      earned: Horizon.badges_earned(progress)
    }
  end

  # The most common type in the leader's party (first seen wins a tie); nil without game data.
  defp gym_type(gym) do
    with %{pokemon: party} <- GameData.trainer(gym.party),
         [_ | _] = types <- Enum.flat_map(party, &types(&1.species)) do
      types |> Enum.uniq() |> Enum.max_by(fn t -> Enum.count(types, &(&1 == t)) end)
    else
      _ -> nil
    end
  end

  defp types(species) do
    case GameData.species(species) do
      %{types: types} -> types
      nil -> []
    end
  end

  defp handle_progress(:question, %{done?: true} = entry, socket) do
    audio = consume_uploaded_entry(socket, entry, fn %{path: path} -> {:ok, File.read!(path)} end)

    Conversation.question(
      socket.assigns.guest_id,
      audio,
      "question" <> Path.extname(entry.client_name)
    )

    {:noreply, socket |> assign(voice_down: false) |> push_event("heard", %{})}
  end

  defp handle_progress(:question, _entry, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("barge_in", _params, socket) do
    Conversation.barge_in(socket.assigns.guest_id)
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

    Conversation.playback_started(socket.assigns.guest_id, timings)
    {:noreply, socket}
  end

  # Only drives CSS and the status line; anything but a known state is ignored.
  def handle_event("talk_state", %{"state" => state}, socket) when state in @talk_states,
    do: {:noreply, assign(socket, talk_state: state)}

  def handle_event("talk_state", _params, socket), do: {:noreply, socket}

  # Start fresh asks first; the confirm form posts to /fresh, which rotates the guest.
  def handle_event("ask_fresh", _params, socket),
    do: {:noreply, assign(socket, confirm_fresh: true)}

  def handle_event("keep_talking", _params, socket),
    do: {:noreply, assign(socket, confirm_fresh: false)}

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

  defp status("idle"), do: "Ready when you are"
  defp status("recording"), do: "Listening to you…"
  defp status("speaking"), do: "Maya is speaking"
  defp status(_uploading_or_waiting), do: "Thinking…"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="talk-screen" class="talk-screen" data-state={@talk_state}>
        <h1 id="talk-heading" class="sr-only">Talk to Maya</h1>

        <section id="trainer-card" class="trainer-card" aria-label="Trainer card">
          <div class="card-ball">
            <div id="pokeball" class="pokeball pokeball-emerald" aria-hidden="true">
              <div class="pokeball-button"></div>
            </div>
            <span class="ball-ring" aria-hidden="true"></span>
          </div>
          <div class="card-meta">
            <span id="location" class="card-label">{@card.location}</span>
            <div id="next-gym" class="card-gym">
              <strong :if={@card.next_gym}>Next gym: {@card.next_gym}</strong>
              <strong :if={!@card.next_gym}>All 8 badges earned</strong>
              <span :if={@card.gym_type} class={"type-chip type-#{@card.gym_type}"}>
                {String.capitalize(@card.gym_type)}
              </span>
            </div>
            <ul id="team" class="card-team" aria-label="Team">
              <li :for={mon <- @card.team} class="mon">
                <span :for={type <- mon.types} class={"type-dot type-#{type}"} aria-hidden="true"></span>
                {mon.name} Lv {mon.level}
              </li>
            </ul>
          </div>
          <div class="card-badges">
            <ul id="badge-case" class="badge-case" aria-label="Badge case">
              <li
                :for={n <- 1..8}
                class="badge-slot"
                data-earned={to_string(n in @card.badges)}
                aria-label={"Badge #{n} of 8"}
              >
              </li>
            </ul>
            <span id="badge-count" class="badge-count">{@card.earned} of 8 badges</span>
          </div>
        </section>

        <p id="talk-status" class="talk-status" role="status" aria-live="polite">
          {status(@talk_state)}<span
            :if={@talk_state == "speaking"}
            class="wave"
            aria-hidden="true"
          ><i></i><i></i><i></i><i></i></span>
        </p>

        <section id="turns" class="turns" aria-label="Last few chats">
          <ol id="conversation" aria-live="polite" aria-label="Conversation">
            <li
              :for={turn <- Enum.take(@turns, -3)}
              class={["turn", turn == List.last(@turns) && "now"]}
            >
              <p
                :if={turn.question == Conversation.nothing_heard()}
                class="question you nothing-heard"
              >
                Maya did not hear anything that time
              </p>
              <p :if={turn.question != Conversation.nothing_heard()} class="question you">
                {turn.question}
              </p>
              <p class="answer maya">{turn.answer}</p>
              <p :if={turn.cut} class="cut">cut short</p>
              <p :if={turn.voice_down} class="voice-down">voice is down</p>
            </li>
          </ol>

          <p :if={@voice_down} id="voice-down" class="voice-down">voice is down</p>

          <section :if={@turns == []} class="poke-facts-box" aria-labelledby="poke-facts-heading">
            <h2 id="poke-facts-heading" class="card-label">Pokémon facts</h2>
            <ul id="poke-facts" class="poke-facts" aria-label="Pokémon facts">
              <li :for={fact <- poke_facts()} class="poke-fact">{fact}</li>
            </ul>
          </section>
        </section>

        <section id="start-fresh" class="start-fresh">
          <button
            :if={not @confirm_fresh}
            id="start-fresh-button"
            type="button"
            class="btn btn-ghost btn-sm"
            phx-click="ask_fresh"
          >
            Start fresh
          </button>
          <.form
            :if={@confirm_fresh}
            for={@fresh_form}
            id="start-fresh-confirm"
            action={~p"/fresh"}
            method="post"
            class="space-y-2"
          >
            <p>
              Start over with a new Conversation and no badges? This one stays saved, but leaves this screen.
            </p>
            <button id="start-fresh-yes" type="submit" class="btn btn-warning btn-sm">
              Yes, start fresh
            </button>
            <button
              id="keep-talking"
              type="button"
              class="btn btn-ghost btn-sm"
              phx-click="keep_talking"
            >
              Keep talking
            </button>
          </.form>
        </section>

        <form id="question-form" phx-change="validate" phx-submit="validate" class="hidden">
          <.live_file_input upload={@uploads.question} />
        </form>

        <div class="talk-dock">
          <button
            id="talk-button"
            type="button"
            class="talk-button"
            phx-hook="TalkHook"
            phx-update="ignore"
            data-state="idle"
            data-sample-rate={@sample_rate}
          >
            <span class="talk-label">
              <svg
                class="mic"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2.2"
                stroke-linecap="round"
                aria-hidden="true"
              >
                <rect x="9" y="3" width="6" height="11" rx="3" /><path d="M5 11a7 7 0 0 0 14 0M12 18v3" />
              </svg>
              <span data-show="idle">Hold to talk</span>
              <span data-show="recording">Release to send</span>
              <span data-show="uploading waiting">One sec…</span>
              <span data-show="speaking">Hold to cut in</span>
            </span>
            <span id="talk-hint" class="talk-hint">
              <span data-show="idle">Ask about your next step</span>
              <span data-show="recording">Let go when you are done</span>
              <span data-show="uploading waiting">Maya is checking her notes</span>
              <span data-show="speaking">She stops right away</span>
            </span>
          </button>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
