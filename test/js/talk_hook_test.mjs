// Pure helpers of the Talk hook. Run with `node --test test/js/*_test.mjs` (built in, no dependencies).
import {test} from "node:test"
import assert from "node:assert/strict"
import {micCloseDelay, audioCanSleep, setAudioSession, holdEndedBy, audioSessionType, wakeAudio,
  playbackStalled, keepChunk, afterTurnType, audioDebugOn} from "../../assets/js/talk_hook.js"

test("micCloseDelay: hidden closes at once, idle waits, a turn in flight never closes", () => {
  assert.equal(micCloseDelay("speaking", false, true, 4000), 0)
  assert.equal(micCloseDelay("idle", false, false, 4000), 4000)
  assert.equal(micCloseDelay("idle", true, false, 4000), null)
  assert.equal(micCloseDelay("waiting", false, false, 4000), null)
})

test("audioCanSleep: only with the mic closed, the button idle and nothing playing (#141)", () => {
  assert.equal(audioCanSleep(false, "idle", 0), true)
  assert.equal(audioCanSleep(true, "idle", 0), false)
  assert.equal(audioCanSleep(false, "idle", 1), false)
  // A hidden page closes the mic mid-answer: Maya finishes the sentence first.
  assert.equal(audioCanSleep(false, "speaking", 2), false)
  assert.equal(audioCanSleep(false, "waiting", 0), false)
})

test("setAudioSession sets the type where the W3C Audio Session API exists", () => {
  const nav = {audioSession: {type: "auto"}}
  setAudioSession(nav, "play-and-record")
  assert.equal(nav.audioSession.type, "play-and-record")
  setAudioSession(nav, "auto")
  assert.equal(nav.audioSession.type, "auto")
})

test("setAudioSession does nothing without the API", () => {
  assert.doesNotThrow(() => setAudioSession({}, "auto"))
})

test("holdEndedBy: the pressing pointer's lift or cancel ends the hold anywhere on the page (#83)", () => {
  // Capture lost, finger lifts over another element: still the pressing pointer, still ends it.
  assert.equal(holdEndedBy(7, {type: "pointerup", pointerId: 7}), "pointerup")
  assert.equal(holdEndedBy(7, {type: "pointercancel", pointerId: 7}), "pointercancel")
  // Another finger, or no hold, never ends it.
  assert.equal(holdEndedBy(7, {type: "pointerup", pointerId: 8}), null)
  assert.equal(holdEndedBy(null, {type: "pointerup", pointerId: 7}), null)
  // A lost capture alone never ends a hold (talk-screen spec, Hold end).
  assert.equal(holdEndedBy(7, {type: "lostpointercapture", pointerId: 7}), null)
})

test("setAudioSession survives a setter that throws", () => {
  const nav = {audioSession: {get type() { return "auto" }, set type(_v) { throw new Error("nope") }}}
  assert.doesNotThrow(() => setAudioSession(nav, "playback"))
})

test("audioSessionType: play-and-record with the mic open, playback while Maya talks, the after-turn type after (#96)", () => {
  // An open mic keeps play-and-record: another type would end the mic track (W3C Audio Session).
  assert.equal(audioSessionType(true, "speaking", "auto"), "play-and-record")
  assert.equal(audioSessionType(true, "idle", "auto"), "play-and-record")
  // Mic closed while Maya talks: "playback", which the iOS silent switch does not mute.
  assert.equal(audioSessionType(false, "speaking", "auto"), "playback")
  assert.equal(audioSessionType(false, "waiting", "auto"), "playback")
  // After the turn: "auto" (#145), or the type the music spike picked.
  assert.equal(audioSessionType(false, "idle", "auto"), "auto")
  assert.equal(audioSessionType(false, "idle", "transient"), "transient")
})

test("wakeAudio resumes any state but running or closed and swallows a refusal (#96)", async () => {
  const calls = []
  const ctx = state => ({state, resume: () => { calls.push(state); return Promise.reject(new Error("no gesture")) }})
  for (const s of ["suspended", "interrupted", "running", "closed"]) await wakeAudio(ctx(s))
  assert.deepEqual(calls, ["suspended", "interrupted"])
  assert.doesNotThrow(() => wakeAudio(null))
})

test("playbackStalled: a clock frozen for the limit is a stall (#96)", () => {
  // The clock moved: the frozen mark resets to now.
  assert.deepEqual(playbackStalled(1.0, 1.2, 500, 900, 2500), [900, false])
  // Frozen, not long enough yet.
  assert.deepEqual(playbackStalled(1.2, 1.2, 900, 2000, 2500), [900, false])
  // Frozen for 2.5 s: onended never fires on a stopped clock.
  assert.deepEqual(playbackStalled(1.2, 1.2, 900, 3400, 2500), [900, true])
})

test("keepChunk: only the current hold's turn, only while waiting or speaking (#96)", () => {
  assert.equal(keepChunk("speaking", 7, 7), true)
  assert.equal(keepChunk("waiting", 7, 7), true)
  // A cut turn's late chunk after the next hold's Answer started.
  assert.equal(keepChunk("speaking", 8, 7), false)
  assert.equal(keepChunk("waiting", 8, null), false)
  assert.equal(keepChunk("recording", 7, 7), false)
  assert.equal(keepChunk("idle", 7, 7), false)
})

test("afterTurnType: only auto, transient or ambient, else auto (music spike)", () => {
  assert.equal(afterTurnType("transient"), "transient")
  assert.equal(afterTurnType("ambient"), "ambient")
  assert.equal(afterTurnType("playback"), "auto")
  assert.equal(afterTurnType(null), "auto")
})

test("audioDebugOn: only ?audio_debug=1", () => {
  assert.equal(audioDebugOn("?audio_debug=1"), true)
  assert.equal(audioDebugOn("?x=2&audio_debug=1"), true)
  assert.equal(audioDebugOn("?audio_debug=0"), false)
  assert.equal(audioDebugOn(""), false)
})
