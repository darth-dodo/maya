// TalkHook: the Talk button as an explicit state machine (ARCHITECTURE.md 1, voice lessons in
// docs/factory-learnings.md). idle -> recording -> uploading -> waiting -> speaking -> idle.
// Records 16 kHz mono 16-bit WAV with Web Audio (ADR-005 fallback, no container support needed)
// and plays the server's pushed PCM (32-bit float little-endian, at data-sample-rate) as it arrives.

const STT_RATE = 16000
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

// 44 byte RIFF header plus 16-bit little-endian mono PCM.
export function encodeWav(samples, rate) {
  const view = new DataView(new ArrayBuffer(44 + samples.length * 2))
  const text = (at, s) => [...s].forEach((c, i) => view.setUint8(at + i, c.charCodeAt(0)))
  text(0, "RIFF")
  view.setUint32(4, 36 + samples.length * 2, true)
  text(8, "WAVE")
  text(12, "fmt ")
  view.setUint32(16, 16, true)
  view.setUint16(20, 1, true) // integer PCM
  view.setUint16(22, 1, true) // mono
  view.setUint32(24, rate, true)
  view.setUint32(28, rate * 2, true)
  view.setUint16(32, 2, true)
  view.setUint16(34, 16, true)
  text(36, "data")
  view.setUint32(40, samples.length * 2, true)
  samples.forEach((s, i) => {
    const c = Math.max(-1, Math.min(1, s))
    view.setInt16(44 + i * 2, c < 0 ? c * 0x8000 : c * 0x7fff, true)
  })
  return new Blob([view], {type: "audio/wav"})
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

// Stops every track and unhooks the capture nodes, so the phone's mic indicator goes off (#79).
// The playback AudioContext stays: iOS only unlocks it inside a gesture.
export function closeMic(mic) {
  if (!mic) return
  mic.stream.getTracks().forEach(t => t.stop())
  mic.node.onaudioprocess = null
  mic.source.disconnect()
  mic.node.disconnect()
}

function concat(chunks) {
  const out = new Float32Array(chunks.reduce((n, c) => n + c.length, 0))
  let at = 0
  for (const c of chunks) { out.set(c, at); at += c.length }
  return out
}

export const TalkHook = {
  mounted() {
    this.sampleRate = Number(this.el.dataset.sampleRate)
    this.postRollMs = Number(this.el.dataset.postRollMs) || 0
    this.sources = []
    this.samples = []
    this.preRoll = []
    this.state = "idle" // the server renders idle on the button and the screen root

    this.el.addEventListener("pointerdown", e => this.press(e))
    this.el.addEventListener("pointerup", () => this.release("pointerup"))
    // A real cancel (app switch, palm rejection) still stops recording and sends the clip.
    this.el.addEventListener("pointercancel", () => this.release("pointercancel"))
    // Only noted: it also follows every pointerup, so releasing on it would end a hold twice,
    // or early when capture is lost mid-hold.
    this.el.addEventListener("lostpointercapture", () => { if (this.pressed) this.lostCapture = true })
    // iOS: keep the touch from starting a scroll or the text loupe under the finger.
    this.el.addEventListener("touchstart", e => e.preventDefault(), {passive: false})
    this.el.addEventListener("contextmenu", e => e.preventDefault())
    // A phone in a pocket never keeps the mic.
    this.onVisibility = () => this.scheduleMicClose()
    document.addEventListener("visibilitychange", this.onVisibility)

    this.handleEvent("heard", () => {
      if (this.state !== "uploading") return
      this.marks.heard = performance.now()
      this.set("waiting")
    })
    this.handleEvent("audio", ({pcm}) => this.play(pcm))
    this.handleEvent("audio_done", () => { this.done = true; this.maybeIdle() })
    this.handleEvent("voice_down", () => { this.stopAudio(); this.set("idle") })
  },

  destroyed() {
    document.removeEventListener("visibilitychange", this.onVisibility)
    clearTimeout(this.tailTimer)
    this.stopAudio()
    this.dropMic()
    this.ctx?.close()
  },

  dropMic() {
    clearTimeout(this.micTimer)
    closeMic(this.mic)
    this.mic = null
    this.preRoll = []
  },

  scheduleMicClose() {
    clearTimeout(this.micTimer)
    if (!this.mic) return
    const delay = micCloseDelay(this.state, this.pressed, document.hidden, MIC_IDLE_MS)
    if (delay === 0) this.dropMic()
    else if (delay != null) this.micTimer = setTimeout(() => this.dropMic(), delay)
  },

  // The button's labels follow its own data-state at once (CSS); the screen root (ring, card,
  // status) follows the server's copy, so a push only when the state changes.
  set(state) {
    if (state !== this.state) this.pushEvent("talk_state", {state})
    this.state = state
    this.el.dataset.state = state
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
    if (this.state === "speaking") {
      // Barge-in: silence at once, then tell the server to cancel the stream. Idle drops the cut
      // turn's late chunks while the mic opens.
      this.stopAudio()
      this.pushEvent("barge_in", {})
      this.set("idle")
    }
    this.el.setPointerCapture?.(e.pointerId)
    // Created and resumed inside the gesture, or iOS keeps it suspended.
    this.ctx ||= new (window.AudioContext || window.webkitAudioContext)()
    this.ctx.resume()
    const hold = (this.hold = {})
    this.pressed = true
    this.pressedAt = performance.now()
    this.micLiveAt = null
    this.lostCapture = false
    this.samples = []
    if (this.mic) {
      // Warm press: the pre-roll heads the clip and the button listens at once.
      this.warm = true
      this.samples = this.preRoll
      this.preRoll = []
      this.micLiveAt = this.pressedAt
      this.recording = true
      return this.set("recording")
    }
    this.warm = false
    let mic
    try {
      mic = await this.openMic()
    } catch (_err) {
      if (this.hold === hold) this.pressed = false
      return
    }
    // Released (or pressed again) while the mic was opening: drop this mic at once.
    if (this.hold !== hold || !this.pressed) return closeMic(mic)
    this.mic = mic
    this.preRoll = []
    this.micLiveAt = performance.now()
    this.recording = true // samples count from the live stream, and only then the button listens
    this.set("recording")
  },

  // Opened on a cold press; stays open for the turn and closes MIC_IDLE_MS after idle (#79, #94).
  async openMic() {
    const stream = await navigator.mediaDevices.getUserMedia({audio: {channelCount: 1, echoCancellation: true, noiseSuppression: true}})
    const source = this.ctx.createMediaStreamSource(stream)
    // shortcut: ScriptProcessorNode is deprecated; move to an AudioWorklet if it glitches on a phone.
    const node = this.ctx.createScriptProcessor(4096, 1, 1)
    const preRollMax = Math.round(this.ctx.sampleRate * PRE_ROLL_MS / 1000)
    node.onaudioprocess = e => {
      const block = new Float32Array(e.inputBuffer.getChannelData(0))
      if (this.recording) this.samples.push(block)
      else this.preRoll = pushPreRoll(this.preRoll, block, preRollMax)
    }
    source.connect(node)
    node.connect(this.ctx.destination) // Chrome only runs the node when it is connected; it outputs silence
    return {stream, source, node}
  },

  // Idempotent: the first pointerup or pointercancel ends the hold, any later one returns. A
  // release before the mic is live sends nothing. The button shows sent at once while the mic
  // keeps recording for the post-roll, so a clipped last word is kept; then the clip uploads.
  release(endedBy) {
    if (!this.pressed) return
    const releasedAt = performance.now()
    const wasRecording = this.recording
    const tail = wasRecording ? this.postRollMs : 0
    this.pressed = false
    this.pushEvent("hold_ended",
      holdReport(endedBy, this.pressedAt, releasedAt, this.lostCapture, this.micLiveAt, this.warm, tail))
    if (!wasRecording) return this.set("idle")

    this.marks = {release: releasedAt}
    this.done = false
    this.reported = false
    this.nextTime = 0
    this.leftover = null
    this.set("uploading")
    this.tailTimer = setTimeout(() => this.send(), tail)
  },

  send() {
    this.recording = false
    const samples = this.samples
    this.samples = []
    if (samples.length === 0) return this.set("idle")
    const wav = encodeWav(downsample(concat(samples), this.ctx.sampleRate, STT_RATE), STT_RATE)
    this.upload("question", [new File([wav], "question.wav", {type: "audio/wav"})])
  },

  play(b64) {
    // A cut turn's late chunks arrive while recording or idle: drop them.
    if (this.state !== "waiting" && this.state !== "speaking") return
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

  stopAudio() {
    for (const s of this.sources) {
      s.onended = null
      try { s.stop() } catch (_err) { /* already stopped */ }
    }
    this.sources = []
    this.nextTime = 0
  },
}
