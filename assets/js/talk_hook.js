// TalkHook: the Talk button as an explicit state machine (ARCHITECTURE.md 1, voice lessons in
// docs/factory-learnings.md). idle -> recording -> uploading -> waiting -> speaking -> idle.
// Streams the hold as 16 kHz mono 16-bit PCM chunks over the LiveView socket while it is held
// (ADR-009: stream_start, audio_chunk, stream_end) and plays the server's pushed PCM (32-bit
// float little-endian, at data-sample-rate) as it arrives.

import {safeStorage} from "./safe_storage.js"

const STT_RATE = 16000
// Playback watchdog (#96, cantastorie ADR-010): polled every 500 ms, a clock frozen 2.5 s stalls.
const STALL_MS = 2500
const STALL_POLL_MS = 500
const AFTER_TURN_KEY = "maya:after_turn_session"
const SPEAKING_KEY = "maya:speaking_session"
const MIC_AFTER_RELEASE_KEY = "maya:mic_after_release"
// 200 ms per chunk: the spec allows 100 to 250 ms (1600 to 4000 samples); only the last is shorter.
const CHUNK_SAMPLES = 3200
// Warm mic (#94): audio kept from just before a press, and how long the mic stays open once
// the button is back to idle (#79: the phone's mic indicator goes off soon after the last turn).
const PRE_ROLL_MS = 300
const MIC_IDLE_MS = 4000

// Averages input samples into each output sample (fromRate >= toRate).
export function downsample(input, fromRate, toRate) {
  if (fromRate === toRate) return input
  const ratio = fromRate / toRate
  const out = new Float32Array(Math.floor(input.length / ratio))
  for (let i = 0; i < out.length; i++) {
    const start = Math.floor(i * ratio)
    const end = Math.min(Math.floor((i + 1) * ratio), input.length)
    let sum = 0
    for (let j = start; j < end; j++) sum += input[j]
    out[i] = sum / Math.max(end - start, 1)
  }
  return out
}

// Float samples as base64 16-bit little-endian PCM (pcm_s16le, what Voxtral realtime reads).
export function int16Base64(samples) {
  const view = new DataView(new ArrayBuffer(samples.length * 2))
  samples.forEach((s, i) => {
    const c = Math.max(-1, Math.min(1, s))
    view.setInt16(i * 2, c < 0 ? c * 0x8000 : c * 0x7fff, true)
  })
  let bin = ""
  const bytes = new Uint8Array(view.buffer)
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i])
  return btoa(bin)
}

// Appends 16 kHz samples to the pending ones and cuts whole chunks of `size`:
// [chunks to send, samples kept for the next block].
export function takeChunks(pending, samples, size) {
  const all = new Float32Array(pending.length + samples.length)
  all.set(pending)
  all.set(samples, pending.length)
  const chunks = []
  let at = 0
  for (; at + size <= all.length; at += size) chunks.push(all.subarray(at, at + size))
  return [chunks, all.subarray(at)]
}

// Voxtral streams pcm as float32 LE: 4 bytes per sample, sample count = completion_tokens.
export function pcmF32ToFloat(bytes) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  const out = new Float32Array(bytes.byteLength >> 2)
  for (let i = 0; i < out.length; i++) out[i] = view.getFloat32(i * 4, true)
  return out
}

// Prepends last chunk's partial sample and holds back this chunk's. Copies with set(), not
// spread: a ~75 KB chunk spread as arguments overflows the call stack.
export function alignF32(leftover, bytes) {
  if (leftover) {
    const joined = new Uint8Array(leftover.length + bytes.length)
    joined.set(leftover)
    joined.set(bytes, leftover.length)
    bytes = joined
  }
  const rem = bytes.length % 4
  return rem ? [bytes.subarray(0, -rem), bytes.slice(-rem)] : [bytes, null]
}

// The hold end report the server logs (#76, #79, #94): which event ended the hold, how long it
// was, whether pointer capture was lost before the release, press to live mic time when the mic
// went live before the release (0 on a warm press), whether the mic was already open, and the
// tail recorded after the release.
export function holdReport(endedBy, pressedAt, releasedAt, lostCapture, micLiveAt, warm, postRollMs) {
  const ms = (from, to) => Math.max(0, Math.round(to - from))
  const report = {ended_by: endedBy, hold_ms: ms(pressedAt, releasedAt), lost_capture: lostCapture,
    warm, post_roll_ms: postRollMs}
  if (micLiveAt != null) report.mic_open_ms = ms(pressedAt, micLiveAt)
  return report
}

// Which event ends the hold, or null: only the pressing pointer's pointerup or pointercancel,
// wherever it lands. After a lost capture the lift targets another element, never the button
// (#83), so the hook listens on the document; a lost capture alone ends nothing.
export function holdEndedBy(heldPointerId, e) {
  const ends = e.type === "pointerup" || e.type === "pointercancel"
  return ends && heldPointerId != null && e.pointerId === heldPointerId ? e.type : null
}

// The pre-roll ring (#94): the blocks heard while the mic is warm and no hold is active, cut to
// the last `max` samples. Only a press ever reads it; everything older is dropped here.
export function pushPreRoll(ring, block, max) {
  const out = [...ring, block]
  let extra = out.reduce((n, b) => n + b.length, 0) - max
  while (extra > 0) {
    if (out[0].length <= extra) {
      extra -= out.shift().length
    } else {
      out[0] = out[0].subarray(extra)
      extra = 0
    }
  }
  return out
}

// When to close a warm mic: at once on a hidden page, after the idle delay once the button is
// idle with no hold, otherwise never (null) while a turn is in flight.
export function micCloseDelay(state, pressed, hidden, idleMs) {
  if (hidden) return 0
  return state === "idle" && !pressed ? idleMs : null
}

// The AudioContext may sleep (suspend) only with the mic closed, the button idle and nothing
// playing: a running context keeps the phone's audio session, so Spotify and the like never get
// it back (#141). A suspended context is not audible (https://w3c.github.io/audio-session/ 6).
export function audioCanSleep(micOpen, state, playing) {
  return !micOpen && state === "idle" && playing === 0
}

// W3C Audio Session (Safari 16.4+, https://w3c.github.io/audio-session/). Feature detected, and
// a throwing setter never breaks the press path.
export function setAudioSession(nav, type) {
  try {
    if (nav.audioSession && nav.audioSession.type !== type) nav.audioSession.type = type
  } catch (_err) { /* no session control: the browser's default */ }
}

// The session type for the moment (#96). An open mic keeps "play-and-record": any other type
// but "auto" stops capture (W3C Audio Session, the type attribute). With the mic closed while
// Maya talks, "playback", which the iOS silent switch does not mute (cantastorie ADR-010). After
// the turn "auto" (#145), or the type the music spike picked (?audio_debug=1). The spike can
// also pick the type while Maya talks (#197), from the release on: a mic closed after the
// post-roll must not flap to the after-turn type during the STT gap.
export function audioSessionType(micOpen, state, afterTurn, duringSpeech = "playback") {
  if (micOpen) return "play-and-record"
  return ["uploading", "waiting", "speaking"].includes(state) ? duringSpeech : afterTurn
}

// Resumes a context in any state but "running" or "closed", Safari's "interrupted" (calls, Siri,
// other audio) included, and swallows a refused resume: outside a gesture iOS may say no
// (https://developer.mozilla.org/en-US/docs/Web/API/AudioContext/resume, cantastorie ADR-010).
export function wakeAudio(ctx) {
  if (ctx && ctx.state !== "running" && ctx.state !== "closed") return ctx.resume().catch(() => {})
}

// The playback watchdog (#96): [ms timestamp the AudioContext clock last moved, stalled?]. A
// suspended or interrupted context freezes currentTime and never fires onended
// (https://webaudio.github.io/web-audio-api/#dom-audiocontext-suspend), so "speaking" would hang.
export function playbackStalled(prevTime, time, since, now, limitMs) {
  const moved = time !== prevTime ? now : since
  return [moved, now - moved >= limitMs]
}

// A pushed chunk plays only for the hold that asked for it, by turn id, and only while waiting
// or speaking: a cut turn's chunks can still be on the socket after the next hold starts (#96).
export function keepChunk(state, currentTurn, chunkTurn) {
  return (state === "waiting" || state === "speaking") && chunkTurn === currentTurn
}

// A Question sent from a form (#95): a typed one counts its Answer time from Send, an edited one
// keeps the hold's release mark, so playback_start_ms still includes the edit.
export function askedMarks(typed, marks, now) {
  return typed || !marks ? {release: now} : marks
}

// The forms whose Send asks Maya a Question (#95); their submit is the gesture that wakes audio.
export const QUESTION_FORMS = ["type-form", "edit-form"]

export function asksMaya(form) {
  return !!form && QUESTION_FORMS.includes(form.id)
}

// Music spike (2026-11-18): the session type set after a turn, picked on the debug readout.
export const AFTER_TURN_TYPES = ["auto", "transient", "ambient"]
// Spike #197: the type while Maya talks with the mic closed, and whether the mic stays warm
// after a release or closes right after the post-roll. The first of each is current behaviour.
export const SPEAKING_TYPES = ["play-and-record", "ambient", "playback"]
export const MIC_AFTER_RELEASE = ["warm", "close"]

// A stored debug pick if it is one of the options, else the first.
export function debugChoice(options, stored) {
  return options.includes(stored) ? stored : options[0]
}

export function afterTurnType(stored) {
  return debugChoice(AFTER_TURN_TYPES, stored)
}

export function debugStatus(sessionType, contextState, micOpen) {
  return `session: ${sessionType || "none"}, context: ${contextState || "none"}, mic: ${micOpen ? "open" : "closed"}`
}

export function audioDebugOn(search) {
  return new URLSearchParams(search).get("audio_debug") === "1"
}

// Stops every track and unhooks the capture nodes, so the phone's mic indicator goes off (#79).
// The AudioContext is kept (iOS only unlocks it inside a gesture) and suspended by the hook.
export function closeMic(mic) {
  if (!mic) return
  mic.stream.getTracks().forEach(t => t.stop())
  mic.node.onaudioprocess = null
  mic.source.disconnect()
  mic.node.disconnect()
}

export const TalkHook = {
  mounted() {
    this.sampleRate = Number(this.el.dataset.sampleRate)
    this.postRollMs = Number(this.el.dataset.postRollMs) || 0
    this.sources = []
    this.pending = new Float32Array(0)
    this.preRoll = []
    this.state = "idle" // the server renders idle on the button and the screen root

    this.el.addEventListener("pointerdown", e => this.press(e))
    // On the document from press to lift, so a lift off the button after a lost capture still
    // ends the hold (#83), in the capture phase so no stopPropagation below can hide it. A real
    // cancel (app switch, palm rejection) still stops recording and sends the clip.
    this.onPointerEnd = e => {
      const endedBy = holdEndedBy(this.pointerId, e)
      if (!endedBy) return
      this.unlistenPointerEnd()
      this.release(endedBy)
    }
    // Only noted: it also follows every pointerup, so releasing on it would end a hold twice,
    // or early when capture is lost mid-hold.
    this.el.addEventListener("lostpointercapture", () => { if (this.pressed) this.lostCapture = true })
    // iOS: keep the touch from starting a scroll or the text loupe under the finger.
    this.el.addEventListener("touchstart", e => e.preventDefault(), {passive: false})
    this.el.addEventListener("contextmenu", e => e.preventDefault())
    // A phone in a pocket never keeps the mic, and a hidden page cuts Maya's turn (#96): iOS
    // freezes its audio, so the Answer stays as text. Back in view, a context that still has
    // something to play is woken (best effort, not a gesture); an idle one stays asleep (#145).
    this.onVisibility = () => {
      if (document.hidden && (this.state === "waiting" || this.state === "speaking")) this.cut()
      if (!document.hidden && !audioCanSleep(!!this.mic, this.state, this.sources.length)) wakeAudio(this.ctx)
      this.scheduleMicClose()
    }
    document.addEventListener("visibilitychange", this.onVisibility)

    this.afterTurn = "auto"
    this.duringSpeech = "playback"
    this.micAfterRelease = "warm"
    if (audioDebugOn(window.location.search)) this.mountAudioDebug()

    this.handleEvent("heard", () => {
      if (this.state !== "uploading") return
      this.marks.heard = performance.now()
      this.set("waiting")
    })
    this.handleEvent("audio", ({pcm, turn}) => this.play(pcm, turn))
    this.handleEvent("audio_done", ({turn}) => {
      if (turn !== this.turn) return // a cut turn's end never ends the current one
      this.done = true
      this.maybeIdle()
    })
    this.handleEvent("voice_down", () => { this.stopAudio(); this.set("idle") })

    // Typed and edited Questions (#95). The Send tap is the gesture: the AudioContext is made and
    // woken there, as a press does, or iOS keeps a typed Question's Answer silent.
    this.onSubmit = e => {
      if (!asksMaya(e.target)) return
      this.ctx ||= new (window.AudioContext || window.webkitAudioContext)()
      wakeAudio(this.ctx)
    }
    document.addEventListener("submit", this.onSubmit, true)
    // The Question is open to edit: its Answer was dropped, so the mic may close while typing.
    this.handleEvent("question_editing", () => { if (!this.pressed && this.state === "waiting") this.set("idle") })
    this.handleEvent("question_cancelled", () => { if (!this.pressed && this.state === "waiting") this.set("idle") })
    // Sent from a form: the server already cut any Answer, the Answer audio carries this turn id.
    this.handleEvent("asked", ({turn, typed}) => {
      if (this.pressed) return
      this.stopAudio()
      this.startTurn(askedMarks(typed, this.marks, performance.now()))
      this.turn = turn
      // The keyboard closes only once the Question is accepted, so an error keeps the field.
      if (typed) document.getElementById("type-form")?.reset()
      document.activeElement?.blur()
      this.set("waiting")
    })
  },

  // Fresh per-turn playback state; every playback timing counts from marks.release.
  startTurn(marks) {
    this.marks = marks
    this.done = false
    this.reported = false
    this.nextTime = 0
    this.leftover = null
  },

  destroyed() {
    document.removeEventListener("visibilitychange", this.onVisibility)
    document.removeEventListener("submit", this.onSubmit, true)
    this.unlistenPointerEnd()
    clearTimeout(this.tailTimer)
    clearInterval(this.debugTimer)
    this.debugBox?.remove()
    this.stopAudio()
    this.dropMic()
    this.ctx?.close()
  },

  // Music spikes (?audio_debug=1, #181, #197): a status line (session type, context state, mic)
  // and pickers for the session while Maya speaks, the mic after release and the session after
  // the turn, kept for the tab in sessionStorage. Fixed on the body, outside the LiveView
  // container: no patch touches it, no layout moves under a finger (#74).
  mountAudioDebug() {
    const store = safeStorage(window, "sessionStorage")
    this.afterTurn = afterTurnType(store.getItem(AFTER_TURN_KEY))
    // The debug default is play-and-record, current behaviour: a warm mic is open while Maya speaks.
    this.duringSpeech = debugChoice(SPEAKING_TYPES, store.getItem(SPEAKING_KEY))
    this.micAfterRelease = debugChoice(MIC_AFTER_RELEASE, store.getItem(MIC_AFTER_RELEASE_KEY))
    const box = (this.debugBox = document.createElement("div"))
    box.id = "audio-debug"
    box.style.cssText = "position:fixed;top:4px;left:4px;z-index:100;padding:4px 6px;font:12px monospace;" +
      "background:var(--color-base-100,#fff);color:var(--color-base-content,#000);border:1px solid currentColor"
    const readout = document.createElement("div")
    readout.id = "audio-debug-status"
    const picker = (id, text, options, key, field) => {
      const select = document.createElement("select")
      select.id = id
      options.forEach(t => select.add(new Option(t, t, false, t === this[field])))
      select.onchange = () => {
        this[field] = debugChoice(options, select.value)
        store.setItem(key, this[field])
        this.syncSession()
      }
      const label = document.createElement("label")
      label.style.display = "block"
      label.append(text, select)
      return label
    }
    box.append(readout,
      picker("audio-debug-speaking", "while Maya speaks: ", SPEAKING_TYPES, SPEAKING_KEY, "duringSpeech"),
      picker("audio-debug-mic", "mic after release: ", MIC_AFTER_RELEASE, MIC_AFTER_RELEASE_KEY, "micAfterRelease"),
      picker("audio-debug-after-turn", "after turn: ", AFTER_TURN_TYPES, AFTER_TURN_KEY, "afterTurn"))
    document.body.append(box)
    // Polled (audioSession has no change event to rely on), written only when the text changes.
    const show = () => {
      const text = debugStatus(navigator.audioSession?.type, this.ctx?.state, !!this.mic)
      if (readout.textContent !== text) readout.textContent = text
    }
    show()
    this.debugTimer = setInterval(show, 500)
  },

  // The audio session follows the mic and the button (audioSessionType); a press opening a mic
  // counts as open, so nothing stops the capture it is about to get.
  syncSession() {
    setAudioSession(navigator,
      audioSessionType(!!this.mic || !!this.pressed, this.state, this.afterTurn, this.duringSpeech))
  },

  unlistenPointerEnd() {
    this.pointerId = null
    document.removeEventListener("pointerup", this.onPointerEnd, true)
    document.removeEventListener("pointercancel", this.onPointerEnd, true)
  },

  dropMic() {
    clearTimeout(this.micTimer)
    closeMic(this.mic)
    const hadMic = !!this.mic
    this.mic = null
    this.preRoll = []
    if (hadMic) this.syncSession()
    this.maybeSleep()
  },

  // A cold press that got no mic (denied, or released first): back to the after-turn type
  // unless a newer press is opening one.
  micNotOpened() {
    if (this.mic || this.pressed) return
    this.syncSession()
    this.maybeSleep()
  },

  // Hands the phone's audio back once Maya is silent and the mic is closed (#141). The next
  // press resumes the context inside the gesture.
  maybeSleep() {
    // Not only "running": a resume() still pending from a press reads "suspended" until it lands.
    if (this.ctx && this.ctx.state !== "closed" && audioCanSleep(!!this.mic, this.state, this.sources.length)) {
      this.ctx.suspend()
    }
  },

  scheduleMicClose() {
    clearTimeout(this.micTimer)
    if (!this.mic) return this.maybeSleep()
    const delay = micCloseDelay(this.state, this.pressed, document.hidden, MIC_IDLE_MS)
    if (delay === 0) this.dropMic()
    else if (delay != null) this.micTimer = setTimeout(() => this.dropMic(), delay)
  },

  // The button's labels follow its own data-state at once (CSS); the screen root (ring, card,
  // status) follows the server's copy, so a push only when the state changes.
  set(state) {
    const changed = state !== this.state
    if (changed) this.pushEvent("talk_state", {state})
    this.state = state
    this.el.dataset.state = state
    if (changed) this.syncSession()
    this.scheduleMicClose()
  },

  // Ignored elements still merge the server's data attributes on every patch
  // (https://hexdocs.pm/phoenix_live_view/bindings.html#dom-patching), which resets the
  // static data-state="idle" mid-hold. This runs in the same patch, before any paint.
  updated() {
    this.el.dataset.state = this.state
  },

  reconnected() {
    this.pushEvent("talk_state", {state: this.state})
  },

  async press(e) {
    e.preventDefault()
    if (this.pressed || this.state === "uploading") return
    // Barge-in: silence at once, then tell the server to cancel the stream. The cut turn's late
    // chunks are dropped by state while the mic opens, then by turn id.
    if (this.state === "speaking") this.cut()
    this.el.setPointerCapture?.(e.pointerId)
    this.pointerId = e.pointerId
    document.addEventListener("pointerup", this.onPointerEnd, true)
    document.addEventListener("pointercancel", this.onPointerEnd, true)
    // Created and resumed inside the gesture, or iOS keeps it suspended. Also wakes it after
    // maybeSleep, or from "interrupted"; on a warm press it is already running, so a no-op.
    this.ctx ||= new (window.AudioContext || window.webkitAudioContext)()
    wakeAudio(this.ctx)
    const hold = (this.hold = {})
    this.pressed = true
    this.pressedAt = performance.now()
    this.micLiveAt = null
    this.lostCapture = false
    if (this.mic) {
      // Warm press: the pre-roll heads the stream and the button listens at once.
      this.warm = true
      this.micLiveAt = this.pressedAt
      this.beginStream()
      return this.set("recording")
    }
    this.warm = false
    let mic
    try {
      mic = await this.openMic()
    } catch (_err) {
      if (this.hold === hold) this.pressed = false
      return this.micNotOpened()
    }
    // Released (or pressed again) while the mic was opening: drop this mic at once.
    if (this.hold !== hold || !this.pressed) {
      closeMic(mic)
      return this.micNotOpened()
    }
    this.mic = mic
    this.preRoll = []
    this.micLiveAt = performance.now()
    this.beginStream() // samples count from the live stream, and only then the button listens
    this.set("recording")
  },

  // One hold is one stream: start, then the pre-roll (empty on a cold press), then live blocks.
  beginStream() {
    // Each hold's own turn id, echoed on its audio (#96). A timestamp, so a reloaded page never
    // reuses the id of a turn still streaming.
    this.turn = Math.max(Date.now(), (this.turn || 0) + 1)
    this.pushEvent("stream_start", {turn: this.turn})
    this.pending = new Float32Array(0)
    this.recording = true
    const preRoll = this.preRoll
    this.preRoll = []
    preRoll.forEach(block => this.stream(block))
  },

  // Downsamples one mic block and sends every whole 200 ms chunk.
  stream(block) {
    const [chunks, rest] = takeChunks(this.pending, downsample(block, this.ctx.sampleRate, STT_RATE), CHUNK_SAMPLES)
    this.pending = rest
    chunks.forEach(c => this.pushEvent("audio_chunk", {audio: int16Base64(c)}))
  },

  // Opened on a cold press; stays open for the turn and closes MIC_IDLE_MS after idle (#79, #94).
  async openMic() {
    setAudioSession(navigator, "play-and-record")
    const stream = await navigator.mediaDevices.getUserMedia({audio: {channelCount: 1, echoCancellation: true, noiseSuppression: true}})
    const source = this.ctx.createMediaStreamSource(stream)
    // shortcut: ScriptProcessorNode is deprecated; move to an AudioWorklet if it glitches on a phone.
    const node = this.ctx.createScriptProcessor(4096, 1, 1)
    const preRollMax = Math.round(this.ctx.sampleRate * PRE_ROLL_MS / 1000)
    node.onaudioprocess = e => {
      const block = new Float32Array(e.inputBuffer.getChannelData(0))
      if (this.recording) this.stream(block)
      else this.preRoll = pushPreRoll(this.preRoll, block, preRollMax)
    }
    source.connect(node)
    node.connect(this.ctx.destination) // Chrome only runs the node when it is connected; it outputs silence
    return {stream, source, node}
  },

  // Idempotent: the first pointerup or pointercancel ends the hold, any later one returns. A
  // release before the mic is live sends nothing. The button shows sent at once while the mic
  // keeps streaming for the post-roll, so a clipped last word is kept; then the stream ends.
  release(endedBy) {
    if (!this.pressed) return
    const releasedAt = performance.now()
    const wasRecording = this.recording
    const tail = wasRecording ? this.postRollMs : 0
    this.pressed = false
    // A touch press only activates on the lift (HTML Standard, activation-triggering input
    // event), so the wake in press() may not take on iOS; this one runs inside pointerup.
    wakeAudio(this.ctx)
    this.pushEvent("hold_ended",
      holdReport(endedBy, this.pressedAt, releasedAt, this.lostCapture, this.micLiveAt, this.warm, tail))
    if (!wasRecording) return this.set("idle")

    this.startTurn({release: releasedAt})
    this.set("uploading")
    this.tailTimer = setTimeout(() => this.endStream(), tail)
  },

  // The last, shorter chunk, then the end; the server answers "heard".
  endStream() {
    this.recording = false
    const rest = this.pending
    this.pending = new Float32Array(0)
    // Spike #197 "close": the mic goes before Maya answers. dropMic only suspends an idle context.
    if (this.micAfterRelease === "close") this.dropMic()
    // Voice went down during the tail: the turn is over, so cancel the hold instead of asking.
    if (this.state !== "uploading") return this.pushEvent("barge_in", {})
    if (rest.length > 0) this.pushEvent("audio_chunk", {audio: int16Base64(rest)})
    this.pushEvent("stream_end", {})
  },

  play(b64, turn) {
    // A cut turn's late chunks: dropped by turn id, and while recording or idle by state.
    if (!keepChunk(this.state, this.turn, turn)) return
    // Hidden after the release: iOS would freeze this audio, so the Answer stays as text.
    if (document.hidden) return this.cut()
    // Suspended or interrupted plays nothing; a refused wake ends in the watchdog, not dead air.
    wakeAudio(this.ctx)
    const [bytes, rest] = alignF32(this.leftover, Uint8Array.from(atob(b64), c => c.charCodeAt(0)))
    this.leftover = rest
    const samples = pcmF32ToFloat(bytes)
    if (samples.length === 0) return

    const buffer = this.ctx.createBuffer(1, samples.length, this.sampleRate)
    buffer.copyToChannel(samples, 0)
    const src = this.ctx.createBufferSource()
    src.buffer = buffer
    src.connect(this.ctx.destination)
    const at = Math.max(this.ctx.currentTime + 0.02, this.nextTime)
    src.start(at)
    this.nextTime = at + buffer.duration
    this.sources.push(src)
    this.watch()
    src.onended = () => {
      this.sources = this.sources.filter(s => s !== src)
      this.maybeIdle()
    }

    if (!this.reported) {
      this.reported = true
      const startsAt = performance.now() + (at - this.ctx.currentTime) * 1000
      const timings = {playback_start_ms: Math.round(startsAt - this.marks.release)}
      if (this.marks.heard) timings.mic_release_ms = Math.round(this.marks.heard - this.marks.release)
      this.pushEvent("playback_started", timings)
    }
    this.set("speaking")
  },

  maybeIdle() {
    if ((this.state === "speaking" || this.state === "waiting") && this.done && this.sources.length === 0) {
      this.set("idle")
    }
  },

  // Ends Maya's turn here and on the server (both events cut it there): silence, then idle.
  cut(event = "barge_in", payload = {}) {
    this.stopAudio()
    this.pushEvent(event, payload)
    this.set("idle")
  },

  // The playback watchdog (#96): while audio is queued and the page is visible, a clock frozen
  // for STALL_MS means onended will never fire. The turn ends and the screen shows voice down.
  watch() {
    if (this.watchdog) return
    this.clockAt = this.ctx.currentTime
    this.clockMovedAt = performance.now()
    this.watchdog = setInterval(() => {
      if (this.sources.length === 0) return this.unwatch()
      const time = this.ctx.currentTime
      const now = performance.now()
      const [movedAt, stalled] = playbackStalled(this.clockAt, time, this.clockMovedAt, now, STALL_MS)
      this.clockAt = time
      this.clockMovedAt = document.hidden ? now : movedAt
      if (!stalled || document.hidden) return
      this.cut("playback_stalled", {context: this.ctx.state})
    }, STALL_POLL_MS)
  },

  unwatch() {
    clearInterval(this.watchdog)
    this.watchdog = null
  },

  stopAudio() {
    this.unwatch()
    for (const s of this.sources) {
      s.onended = null
      try { s.stop() } catch (_err) { /* already stopped */ }
    }
    this.sources = []
    this.nextTime = 0
  },
}
