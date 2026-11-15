// TalkHook: the Talk button as an explicit state machine (ARCHITECTURE.md 1, voice lessons in
// docs/factory-learnings.md). idle -> recording -> uploading -> waiting -> speaking -> idle.
// Records 16 kHz mono 16-bit WAV with Web Audio (ADR-005 fallback, no container support needed)
// and plays the server's pushed PCM (32-bit float little-endian, at data-sample-rate) as it arrives.

const STT_RATE = 16000

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

function concat(chunks) {
  const out = new Float32Array(chunks.reduce((n, c) => n + c.length, 0))
  let at = 0
  for (const c of chunks) { out.set(c, at); at += c.length }
  return out
}

export const TalkHook = {
  mounted() {
    this.sampleRate = Number(this.el.dataset.sampleRate)
    this.sources = []
    this.samples = []
    this.state = "idle" // the server renders idle on the button and the screen root

    this.el.addEventListener("pointerdown", e => this.press(e))
    this.el.addEventListener("pointerup", () => this.release())
    this.el.addEventListener("pointercancel", () => this.release())
    this.el.addEventListener("contextmenu", e => e.preventDefault())

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
    this.stopAudio()
    this.stream?.getTracks().forEach(t => t.stop())
    this.ctx?.close()
  },

  // The button's labels follow its own data-state at once (CSS); the screen root (ring, card,
  // status) follows the server's copy, so a push only when the state changes.
  set(state) {
    if (state !== this.state) this.pushEvent("talk_state", {state})
    this.state = state
    this.el.dataset.state = state
  },

  reconnected() {
    this.pushEvent("talk_state", {state: this.state})
  },

  async press(e) {
    e.preventDefault()
    if (this.state === "uploading" || this.state === "recording") return
    if (this.state === "speaking") {
      // Barge-in: silence at once, then tell the server to cancel the stream.
      this.stopAudio()
      this.pushEvent("barge_in", {})
    }
    this.el.setPointerCapture?.(e.pointerId)
    // Created and resumed inside the gesture, or iOS keeps it suspended.
    this.ctx ||= new (window.AudioContext || window.webkitAudioContext)()
    this.ctx.resume()
    this.pressed = true
    this.samples = []
    this.set("recording")
    try {
      await this.openMic()
    } catch (_err) {
      this.set("idle")
      return
    }
    this.recording = this.pressed
  },

  async openMic() {
    if (this.stream) return
    this.stream = await navigator.mediaDevices.getUserMedia({audio: {channelCount: 1, echoCancellation: true, noiseSuppression: true}})
    const source = this.ctx.createMediaStreamSource(this.stream)
    // shortcut: ScriptProcessorNode is deprecated; move to an AudioWorklet if it glitches on a phone.
    const node = this.ctx.createScriptProcessor(4096, 1, 1)
    node.onaudioprocess = e => {
      if (this.recording) this.samples.push(new Float32Array(e.inputBuffer.getChannelData(0)))
    }
    source.connect(node)
    node.connect(this.ctx.destination) // Chrome only runs the node when it is connected; it outputs silence
  },

  release() {
    if (this.state !== "recording") return
    const releasedAt = performance.now()
    this.pressed = false
    this.recording = false
    if (this.samples.length === 0) return this.set("idle")

    const wav = encodeWav(downsample(concat(this.samples), this.ctx.sampleRate, STT_RATE), STT_RATE)
    this.samples = []
    this.marks = {release: releasedAt}
    this.done = false
    this.reported = false
    this.nextTime = 0
    this.leftover = null
    this.set("uploading")
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
