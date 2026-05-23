# Echo Cave

An audio-first cave exploration game designed for blind and sighted players. The cave is generated procedurally and navigated by sound — drips, wind, hums, and chimes hint at room shape and depth. Sighted players can opt into a visual layer; blind players have parity (or an advantage) by design.

**Live demo:** http://134.209.6.140:8080/echo-game/

## What this is

A single-page web game served as one HTML file. No build system. No backend. All state stored in `localStorage`. Voice narration uses pre-rendered ElevenLabs audio clips ("George", a warm British storyteller voice).

## Core design

- **Audio-first:** the game is fully playable with eyes closed
- **George the narrator:** every gameplay event has a pre-rendered voice clip; the system voice is a fallback only for genuinely dynamic content
- **Multi-level descent:** reach the exit, the cave deepens; spine grows ~2 rooms per level
- **Crystal Grotto theme:** alternate audio palette + visual cyan accent
- **Story journal:** per-cave lore beats, theme-aware prose, persistent across descents within a session

## Quick start

Serve this folder over HTTP. Anything works:

```bash
python3 -m http.server 8080
# or
npx serve .
```

Open `http://localhost:8080/` in a browser. Save state lives in `localStorage` under `echo-cave-v3`.

## File layout

```
index.html             # ~5,800 lines — game logic, UI, audio pipeline
sw.js                  # Service worker — precache + runtime voice cache
manifest.json          # PWA manifest
audio/
  bed-*.wav            # 8 atmospheric beds (Classic + Crystal Grotto, base/shallow/mid/deep)
  drip-loop.wav        # Landmark sound loops (5 types)
  step-*.wav           # Footstep impacts (4 floor textures)
  friction-*.wav       # Continuous slide sounds (4 floor textures)
  welcome-music.mp3    # Welcome screen ambient track
  voice/
    manifest.json      # 689 entries — text → WAV index
    *.wav              # ~689 voice clips for the corpus
tests/                 # Playwright + unit test suites (see Tests section)
icons/                 # PWA icons (192, 512, 180, maskable-512)
LICENSE                # Proprietary license; commercial use restricted
README.md              # This file
```

## Voice corpus

`audio/voice/manifest.json` is the canonical index. Each entry has:

```json
"stem-name": { "text": "the spoken text", "wav": "audio/voice/stem-name.wav" }
```

The runtime `voiceLookup()` function tries:
1. Full-string exact match against any entry's text
2. Sentence-split: split on `. ! ?` and look up each sentence; if all match, stitch them at runtime

This is how 613 atomic clips can compose tens of thousands of utterances. Adding a new line of dialog only requires a clip for any new atomic sentence.

## Schema versioning

`localStorage` saves include a `_schema` field. When the game's `SCHEMA_VERSION` is bumped, the `MIGRATIONS` table in `index.html` runs forward-only migrations. Legacy keys (`echo-cave`, `echo-cave-v2`) are read once and migrated to the current key on first load.

## Build tag + cache busting

`window.ECHO_BUILD` is the cache-bust tag (see top of `index.html`, around line 16). Audio fetches append `?v=<ECHO_BUILD>` so phones never serve stale `.wav` files. Bump it whenever audio is regenerated or significant code changes ship.

**Deploy checklist — must bump both:**
1. `window.ECHO_BUILD` in `index.html`
2. `const BUILD` in `sw.js` (must match)

If only one is bumped, the service worker keeps serving stale cached assets. `sw.js` is network-first for HTML so the page itself updates immediately on next visit.

## Kill switches (URL flags for emergency rollback)

```
?novoice    Disable voice corpus, fall through to system voice
?nomusic    Disable welcome music + cave beds
?safemode   All audio disabled (last-resort recovery)
?fresh=1    Wipe localStorage, start as new player
?nogate     Skip welcome-speech gate (dev/test)
```

Use these if a bad deploy ships and you need users to remain functional while you fix forward.

## Diagnostics

Open Settings → Diagnostics for an on-device readout: build tag, audio context state, voice clip load progress, speak() outcome counts, A11y audit results, recent speak events. The "📡 Live link" toggle silently fires `/diag/<session>/...` GET requests for each event so a developer tailing the server log can watch the user's session in real time. No data leaves the device unless Live Link is on.

## Tests

All test suites live under `tests/` in this repo:

```bash
npm test          # runs the two primary suites (unit + e2e)
npm run test:all  # also runs fuzz + cache + rotor suites
```

Or directly:

```bash
python3 tests/test_echo_game.py       # unit checks
python3 tests/test_echo_game_e2e.py   # end-to-end Playwright
python3 tests/test_echo_game_fuzz.py  # input fuzzer
python3 tests/test_cache_lookup.py    # voice-corpus lookup checks
python3 tests/test_rotor_fuzz.py      # rotor gesture fuzzer
```

Coverage: welcome flow, panels, gestures, settings, audio assets, achievements, journal, descent, SVG schematic, voice resolution, gesture blocks, panel modal interactions, rotor menu.

**Note:** the tests assume the game is served at `http://localhost:8080/echo-game/`. If you run `npm run serve` directly from this repo (which serves at `http://localhost:8080/`), update the `BASE` constant at the top of each test file to `http://localhost:8080`.

## Dependencies

None. Single HTML file, no npm, no bundler, no framework.

## Browser support

- iOS Safari 14+ (primary target — extensive iOS-specific audio context recovery)
- Desktop Chrome / Safari / Firefox (current)
- Tested cross-device via Playwright; production behavior has been observed on real iPhone

## Known iOS-specific behaviors handled

- AudioContext `interrupted` state recovery on visibility change, focus, touch, click
- Double-tap-to-zoom guard (preserves pinch-zoom)
- HTTP-context Clipboard API fallback (uses `execCommand('copy')` then textarea-select)
- Voice clip preload prioritization (welcome → intro → tutorial → bulk)

## Accessibility

- ARIA dialog + `aria-modal` on every panel
- `aria-label` on every interactive element
- Live regions for status updates (selectively disabled where George duplicates them — see Settings → Diagnostics for current ARIA audit pass count)
- Auto Listen Mode after 4 seconds of stillness
- Two-finger tap = teleport home (works without seeing the dpad)
- Double-tap-and-hold = rotor menu (VoiceOver-style action wheel)

## License & ownership

See `LICENSE`. Audio clips are subject to the ElevenLabs subscription terms of the account that generated them. Transfer of ownership requires confirmation of the appropriate ElevenLabs license tier.
