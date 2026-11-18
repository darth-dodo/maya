defmodule MayaWeb.TalkLive do
  @moduledoc """
  The Talk screen at `/talk` (ARCHITECTURE.md 1). It only draws: the Question arrives as a
  stream of 16 kHz PCM chunks from the TalkHook while the button is held (ADR-009), the
  Conversation does the work and reports live partial text, and Answer audio
  goes back to the hook as pushed PCM events (ADR-005). It talks to the Conversation of the
  guest in the session (ADR-008).
  """
  use MayaWeb, :live_view

  alias Maya.Conversation
  alias Maya.Events
  alias Maya.GameData
  alias Maya.Horizon
  alias Maya.Voice.Turn

  require Logger

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

  # How a hold can end (#76); lostpointercapture is only a flag, it never ends a hold.
  @hold_ends ~w(pointerup pointercancel)
  # Recording kept after release so a clipped last word is heard (#94); it is streamed too.
  @post_roll_ms 150

  def poke_facts, do: @poke_facts

  @impl true
  def mount(_params, %{"guest_id" => guest_id}, socket) do
    progress = GameData.progress(guest_id)

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
       progress: progress,
       card: trainer_card(progress),
       talk_state: "idle",
       voice_down: false,
       confirm_fresh: false,
       fresh_form: to_form(%{}),
       sample_rate: Application.fetch_env!(:maya, :voice)[:tts_sample_rate],
       post_roll_ms: @post_roll_ms,
       live_question: nil,
       pending_question: nil,
       editing: nil,
       edit_line: nil,
       can_undo: false
     )}
  end

  # A tab opened before guests reconnects with a session that has none: reload the page,
  # so the browser pipeline gives it a guest.
  def mount(_params, _session, socket), do: {:ok, redirect(socket, to: ~p"/talk")}

  # Read on mount, then redrawn from each Progress the Conversation reports after an Event (#89).
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

  # One hold is one Question: start, chunks, end. The Conversation validates each chunk.
  @impl true
  def handle_event("stream_start", _params, socket) do
    Conversation.stream_start(socket.assigns.guest_id)
    {:noreply, assign(socket, voice_down: false, live_question: nil, pending_question: nil)}
  end

  def handle_event("audio_chunk", %{"audio" => b64}, socket) when is_binary(b64) do
    Conversation.audio_chunk(socket.assigns.guest_id, b64)
    {:noreply, socket}
  end

  def handle_event("audio_chunk", _params, socket), do: {:noreply, socket}

  def handle_event("stream_end", _params, socket) do
    Conversation.stream_end(socket.assigns.guest_id)
    {:noreply, push_event(socket, "heard", %{})}
  end

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

  # Drives CSS and the status line, and a moment away from idle closes the Team editor, so a
  # hold is never covered (team-edit); anything but a known state is ignored.
  def handle_event("talk_state", %{"state" => "idle"}, socket),
    do: {:noreply, assign(socket, talk_state: "idle")}

  def handle_event("talk_state", %{"state" => state}, socket) when state in @talk_states,
    do: {:noreply, socket |> assign(talk_state: state) |> close_editor()}

  def handle_event("talk_state", _params, socket), do: {:noreply, socket}

  # Evidence for #76, #79 and #94: how each hold ended, how long it was, press to live mic
  # time, whether the mic was already warm and the recorded tail after release, never audio or
  # text. The mic time is "none" when the hold ended before it was live.
  def handle_event(
        "hold_ended",
        %{"ended_by" => by, "hold_ms" => ms, "warm" => warm, "post_roll_ms" => tail} = params,
        socket
      )
      when by in @hold_ends and is_integer(ms) and ms >= 0 and is_boolean(warm) and
             is_integer(tail) and tail >= 0 do
    Logger.info(
      "hold ended by #{by} after #{ms} ms, lost capture: #{params["lost_capture"] == true}, " <>
        "mic open: #{ms_or_none(params["mic_open_ms"])}, warm: #{warm}, post roll: #{tail} ms"
    )

    {:noreply, socket}
  end

  def handle_event("hold_ended", _params, socket), do: {:noreply, socket}

  # Start fresh asks first; the confirm form posts to /fresh, which rotates the guest.
  def handle_event("ask_fresh", _params, socket),
    do: {:noreply, assign(socket, confirm_fresh: true)}

  def handle_event("keep_talking", _params, socket),
    do: {:noreply, assign(socket, confirm_fresh: false)}

  # The Team editor (team-edit): idle only, and every action is the Event voice writes, through
  # Events.log/3 with the member's slot, so a stale screen changes nothing.
  def handle_event("edit_mon", %{"slot" => slot}, %{assigns: %{talk_state: "idle"}} = socket) do
    with {n, ""} when n >= 1 <- Integer.parse(to_string(slot)),
         %{"species" => species} <- Enum.at(socket.assigns.progress.team, n - 1) do
      {:noreply,
       assign(socket, editing: %{slot: n, species: species}, edit_line: nil, can_undo: false)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("edit_mon", _params, socket), do: {:noreply, socket}

  def handle_event("close_editor", _params, socket), do: {:noreply, close_editor(socket)}

  def handle_event("save_level", %{"level" => level}, socket) do
    # A non-number goes through as is, so Events gives its own refused line.
    level =
      case Integer.parse(level) do
        {n, ""} -> n
        _ -> level
      end

    {:noreply, edit(socket, "set_level", %{"level" => level})}
  end

  def handle_event("edit", %{"kind" => kind}, socket)
      when kind in ~w(set_lead deposited released),
      do: {:noreply, edit(socket, kind, %{})}

  # Client params are untrusted: anything else is ignored, never a crash of the voice session.
  def handle_event(event, _params, socket) when event in ~w(save_level edit),
    do: {:noreply, socket}

  def handle_event(
        "undo_edit",
        _params,
        %{assigns: %{talk_state: "idle", can_undo: true}} = socket
      ),
      do: {:noreply, log_edit(socket, "undo", %{}, socket.assigns.editing)}

  def handle_event("undo_edit", _params, socket), do: {:noreply, socket}

  @impl true
  # A turn on screen replaces the pending Question.
  def handle_info({:conversation, {:turns, turns}}, socket),
    do: {:noreply, assign(socket, turns: turns, live_question: nil, pending_question: nil)}

  # Sent after every agent stage; an unchanged Progress leaves the card as it is.
  def handle_info(
        {:conversation, {:progress, progress}},
        %{assigns: %{progress: progress}} = socket
      ),
      do: {:noreply, socket}

  def handle_info({:conversation, {:progress, progress}}, socket),
    do: {:noreply, assign(socket, progress: progress, card: trainer_card(progress))}

  def handle_info({:conversation, {:partial, text}}, socket),
    do: {:noreply, assign(socket, live_question: text)}

  def handle_info({:conversation, {:question, text}}, socket),
    do: {:noreply, assign(socket, live_question: nil, pending_question: text)}

  def handle_info({:conversation, {:audio, pcm}}, socket),
    do: {:noreply, push_event(socket, "audio", %{pcm: Base.encode64(pcm)})}

  def handle_info({:conversation, :audio_done}, socket),
    do: {:noreply, push_event(socket, "audio_done", %{})}

  # A failed TTS flags its turn; only a failed STT (no turn) needs the note on its own.
  def handle_info({:conversation, :voice_down}, socket) do
    on_turn? = match?(%Turn{voice_down: true}, List.last(socket.assigns.turns))

    {:noreply,
     socket
     |> assign(voice_down: not on_turn?, live_question: nil, pending_question: nil)
     |> push_event("voice_down", %{})}
  end

  defp close_editor(socket), do: assign(socket, editing: nil, edit_line: nil, can_undo: false)

  defp edit(%{assigns: %{talk_state: "idle", editing: %{} = editing}} = socket, kind, extra) do
    details = Map.merge(%{"species" => editing.species, "slot" => editing.slot}, extra)
    log_edit(socket, kind, details, editing)
  end

  defp edit(socket, _kind, _extra), do: socket

  defp log_edit(socket, kind, details, editing) do
    case Events.log(socket.assigns.progress, kind, details) do
      {:ok, line, progress} ->
        assign(socket,
          progress: progress,
          card: trainer_card(progress),
          editing: follow(editing, progress.team),
          edit_line: line,
          # Undo only after a confirm that wrote an Event; it undoes the Guest's last Event.
          can_undo: kind != "undo" and progress != socket.assigns.progress
        )

      {:refused, line} ->
        assign(socket, edit_line: line, can_undo: false)
    end
  end

  # The editor follows its member to a new slot (a new lead, an Undo).
  # shortcut: with two of one species it follows the first; upgrade to a member id if that bites.
  defp follow(nil, _team), do: nil

  defp follow(editing, team) do
    case {edited(editing, team), Enum.find_index(team, &(&1["species"] == editing.species))} do
      {nil, i} when is_integer(i) -> %{editing | slot: i + 1}
      _same_or_gone -> editing
    end
  end

  # The member being edited, or nil once it left the Team (moved to the PC box, released).
  defp edited(%{slot: slot, species: species}, team) do
    case Enum.at(team, slot - 1) do
      %{"species" => ^species} = member -> member
      _gone -> nil
    end
  end

  defp ms_or_none(ms) when is_integer(ms) and ms >= 0, do: "#{ms} ms"
  defp ms_or_none(_missing), do: "none"

  # The collapsed Team line (team-collapse): the first @team_shown names, the rest as "+N" in
  # its own span so it never truncates; the label names everyone for screen readers.
  @team_shown 3

  defp team_names([]), do: "No Team yet"
  defp team_names(team), do: team |> Enum.take(@team_shown) |> names()

  defp team_more(team), do: max(length(team) - @team_shown, 0)

  defp team_label([]), do: "Team: No Team yet"
  defp team_label(team), do: "Team: " <> names(team)

  defp names(team), do: Enum.map_join(team, ", ", & &1.name)

  defp status("idle"), do: "Ready when you are"
  defp status("recording"), do: "Listening to you…"
  defp status("speaking"), do: "Maya is speaking"
  defp status(_uploading_or_waiting), do: "Thinking…"

  # A fixed overlay above the Talk dock, so opening it changes no layout height (#74). Focus
  # moves to the heading (the level input would open the phone keyboard). Close and Escape focus
  # the member's chip by its slot, which follows a new lead (a focus stack would return to the
  # old position), or the Team summary once it left the Team.
  attr :member, :map, doc: "the card member being edited, nil once it left the Team"
  attr :slot, :integer
  attr :line, :string
  attr :can_undo, :boolean

  defp team_editor(assigns) do
    back = if assigns.member, do: "#mon-#{assigns.slot}", else: "#team-summary"

    assigns =
      assign(assigns,
        form: assigns.member && to_form(%{"level" => assigns.member.level}),
        close: JS.push("close_editor") |> JS.focus(to: back)
      )

    ~H"""
    <section
      id="team-editor"
      class="team-editor"
      role="dialog"
      aria-modal="false"
      aria-labelledby="team-editor-heading"
      phx-mounted={JS.focus(to: "#team-editor-heading")}
      phx-window-keydown={@close}
      phx-key="Escape"
    >
      <h2 id="team-editor-heading" class="team-editor-heading" tabindex="-1">
        {if @member, do: "#{@member.name} Lv #{@member.level}", else: "Team"}
      </h2>
      <p id="team-editor-line" class="team-editor-line" role="status" aria-live="polite">{@line}</p>
      <.form
        :if={@member}
        for={@form}
        id="level-form"
        class="team-editor-level"
        phx-submit="save_level"
      >
        <.input
          field={@form[:level]}
          id="team-level"
          type="number"
          inputmode="numeric"
          label="Level"
          class="input team-editor-input"
        />
        <button type="submit" class="btn btn-primary">Save level</button>
      </.form>
      <div class="team-editor-actions">
        <button :if={@can_undo} type="button" class="btn" phx-click="undo_edit">Undo</button>
        <%= if @member do %>
          <button type="button" class="btn" phx-click="edit" phx-value-kind="set_lead">
            Set as lead
          </button>
          <button type="button" class="btn" phx-click="edit" phx-value-kind="deposited">
            Move to PC box
          </button>
          <button type="button" class="btn" phx-click="edit" phx-value-kind="released">
            Remove
          </button>
          <%!-- The PC box list lands in part D (Issue 170) --%>
          <button type="button" class="btn" disabled>PC box</button>
        <% end %>
        <button
          id="team-editor-close"
          type="button"
          class="btn btn-ghost"
          phx-click={@close}
        >
          Close
        </button>
      </div>
    </section>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} link={:home}>
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
            <p id="card-eyebrow" class="card-eyebrow">
              <span id="location" class="card-label">{@card.location}</span>
              <span id="badge-count" class="badge-count">{@card.earned} of 8 badges</span>
            </p>
            <div id="next-gym" class="card-gym">
              <strong :if={@card.next_gym}>Next gym: {@card.next_gym}</strong>
              <strong :if={!@card.next_gym}>All 8 badges earned</strong>
              <span :if={@card.gym_type} class={"type-chip type-#{@card.gym_type}"}>
                {String.capitalize(@card.gym_type)}
              </span>
            </div>
            <ul id="badge-case" class="badge-case" aria-label="Badge case">
              <li
                :for={n <- 1..8}
                class="badge-slot"
                data-earned={to_string(n in @card.badges)}
                aria-label={"Badge #{n} of 8"}
              >
              </li>
            </ul>
          </div>
          <%!-- Collapsed each visit; ignore_attributes keeps the Guest's open through patches (team-collapse) --%>
          <details
            id="team-details"
            class="card-team-details"
            phx-mounted={JS.ignore_attributes(["open"])}
          >
            <summary
              id="team-summary"
              class="team-summary"
              aria-label={team_label(@card.team)}
            >
              <span class="team-names">{team_names(@card.team)}</span>
              <span :if={team_more(@card.team) > 0} class="team-more" aria-hidden="true">
                +{team_more(@card.team)}
              </span>
              <span class="team-chevron" aria-hidden="true"></span>
            </summary>
            <ul id="team" class="card-team" aria-label="Team">
              <li :for={{mon, slot} <- Enum.with_index(@card.team, 1)}>
                <button
                  type="button"
                  class="mon"
                  aria-label={"Edit #{mon.name} Lv #{mon.level}"}
                  id={"mon-#{slot}"}
                  phx-click={
                    JS.push("edit_mon", value: %{slot: slot})
                    |> JS.focus(to: "#team-editor-heading")
                  }
                >
                  <span :for={type <- mon.types} class={"type-dot type-#{type}"} aria-hidden="true"></span>
                  {mon.name} Lv {mon.level}
                </button>
              </li>
            </ul>
          </details>
        </section>

        <.team_editor
          :if={@editing}
          member={edited(@editing, @progress.team) && Enum.at(@card.team, @editing.slot - 1)}
          slot={@editing.slot}
          line={@edit_line}
          can_undo={@can_undo}
        />

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
            <li :if={@live_question || @pending_question} class="turn now">
              <p :if={@live_question} id="live-question" class="question you live">
                {@live_question}
              </p>
              <p :if={@pending_question} id="pending-question" class="question you">
                {@pending_question}
              </p>
            </li>
          </ol>

          <p :if={@voice_down} id="voice-down" class="voice-down">voice is down</p>

          <section :if={@turns == []} class="poke-facts-box" aria-labelledby="poke-facts-heading">
            <h2 id="poke-facts-heading" class="card-label">Poké facts</h2>
            <ul id="poke-facts" class="poke-facts" aria-label="Poké facts">
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
            <button id="start-fresh-yes" type="submit" class="btn btn-error btn-sm">
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

        <div class="talk-dock">
          <button
            id="talk-button"
            type="button"
            class="talk-button"
            phx-hook="TalkHook"
            phx-update="ignore"
            data-state="idle"
            data-sample-rate={@sample_rate}
            data-post-roll-ms={@post_roll_ms}
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
