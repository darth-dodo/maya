# Proposal

GitHub Issues: #76 (fixes a regression from #74, B3 Talk screen) and #79 (release the mic after each hold).

#79: `openMic()` returned early once a stream existed and only `destroyed()` stopped its tracks, so the mic stayed live (iOS orange dot) for the whole page session.

## Why

Since #74, holding the Talk button on iPhone (Chrome and Safari, both WebKit) ends the hold too soon. Two things changed under a held finger in #74: the trainer card shrinks on `recording`, so the page reflows under the touch, and every moment push re-renders the screen, which merges the button's static `data-state="idle"` back onto the `phx-update="ignore"` button (LiveView merges data attributes on ignored elements), so its label swaps mid-hold. WebKit can end a touch with `pointercancel` when the page moves under it, and the hook releases on `pointercancel`. This is a hypothesis until a phone run confirms it.

## What Changes

- The card stays full while `recording` and shrinks only from `uploading` and `waiting`.
- The Talk hook restores its own `data-state` after every patch, so the server never resets the button mid-hold; the screen root keeps the server's moment.
- The button's children take no pointer events, so the touch target never changes when a label swaps; `touchstart` is prevented (non-passive) so iOS starts no scroll or loupe.
- Release is idempotent: the first `pointerup` or `pointercancel` ends the hold, `lostpointercapture` is only noted.
- Each hold reports how it ended (`pointerup` or `pointercancel`), its length in ms, whether capture was lost first and the press to live mic time; the server logs it at info level, with no audio or text.
- Each press opens a fresh mic and the button shows `recording` only once the stream is live; release and cancel stop every track and disconnect the capture nodes. The playback AudioContext stays (iOS unlock).

Out of scope: live transcription (#75), STT changes (#68).

## Capabilities

### Modified Capabilities
- `talk-screen`: the hold end report, the button keeping its own state, and no card shrink while `recording`.

## Impact

- Changed: `assets/js/talk_hook.js`, `assets/css/app.css`, `lib/maya_web/live/talk_live.ex`, `test/maya_web/live/talk_live_test.exs`.
- No new dependencies. The voice loop path is unchanged apart from one fire and forget `hold_ended` push on release.
