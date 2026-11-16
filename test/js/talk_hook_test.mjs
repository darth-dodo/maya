// Pure helpers of the Talk hook. Run with `node --test test/js/*_test.mjs` (built in, no dependencies).
import {test} from "node:test"
import assert from "node:assert/strict"
import {micCloseDelay, audioCanSleep, setAudioSession} from "../../assets/js/talk_hook.js"

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
