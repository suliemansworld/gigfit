# Echo Cave

An audio-first cave exploration game designed for blind and sighted players. The cave is generated procedurally and navigated by sound — drips, wind, hums, and chimes hint at room shape and depth. Sighted players can opt into a visual layer; blind players have parity (or an advantage) by design.

## What this is

A single-page web game plus a hardened Capacitor iOS shell. There is no backend, account, advertising, analytics, or remote game content. Web saves use `localStorage`; the iOS app mirrors its save through native Preferences. Voice narration uses pre-rendered ElevenLabs audio clips ("George", a warm British storyteller voice).

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

## iOS app

The iOS target is iPhone-only, supports iOS 15+, bundles all game content, and uses Capacitor 8 with Swift Package Manager. Native integrations cover durable saves, haptics, sharing, screen-reader state, audio-session interruptions, headphone disconnects, and accessibility custom actions.

Requirements for an App Store archive:

- Node 22+
- Xcode 26+ on a supported Mac
- Active access to Apple Team `36R3VCWWUJ` and an App Store Connect record; the Xcode targets preselect that team for automatic signing

```bash
npm install
npm run ios:sync       # builds compressed AAC narration and updates Xcode
npm run ios:open       # opens ios/App/App.xcodeproj
```

The current bundle identifier is `com.suliemansworld.echocave`. `npm run build:ios` converts the 610 WAV narration files into cached 96 kbps AAC outputs without modifying the source recordings. The generated `www/`, native `public/`, and `.build/` directories are intentionally ignored.

## File layout

```
index.html             # ~5,800 lines — game logic, UI, audio pipeline
sw.js                  # Service worker — precache + runtime voice cache
manifest.json          # PWA manifest
capacitor.config.json  # Native app identity and bundled-web configuration
scripts/build-web.mjs  # Reproducible web/iOS bundle builder + AAC conversion
ios/                   # Xcode project, Swift bridge, privacy manifest, UI tests
docs/app-store/        # Store copy, review notes, labels, TestFlight/release plans
audio/
  bed-*.wav            # 8 atmospheric beds (Classic + Crystal Grotto, base/shallow/mid/deep)
  drip-loop.wav        # Landmark sound loops (5 types)
  step-*.wav           # Footstep impacts (4 floor textures)
  friction-*.wav       # Continuous slide sounds (4 floor textures)
  welcome-music.mp3    # Welcome screen ambient track
  voice/
    manifest.json      # 689 entries — text → WAV index
    *.wav / *.mp3      # 689 source voice clips for the corpus
tests/                 # Static, Chromium, WebKit, E2E, and fuzz suites
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

This is how 689 atomic clips can compose tens of thousands of utterances. Adding a new line of dialog only requires a clip for any new atomic sentence.

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

Open Settings → Diagnostics for an on-device readout: build tag, audio context state, voice clip load progress, speak() outcome counts, accessibility audit results, and recent speak events. Diagnostics are local-only. The earlier remote “Live Link” and `/diag/` request path were removed for the private, no-data App Store build.

## Tests

All test suites live under `tests/` in this repo:

```bash
python3 -m pip install -r requirements-dev.txt
python3 -m playwright install chromium webkit
npm test                 # static checks plus primary Chromium suites
npm run test:all         # static, E2E, and fuzz suites
npm run test:browsers    # repeat browser suites in Chromium and WebKit
npm run test:static      # install-free manifest/audio/cache integrity gate
```

Coverage: welcome flow, panels, gestures, settings, audio assets, achievements, journal, descent, SVG schematic, voice resolution, gesture blocks, panel modal interactions, rotor menu.

The runner starts an isolated local server automatically. Override its URL with `ECHO_BASE_URL` and a browser with `ECHO_BROWSER=chromium|webkit`. The Xcode project also includes an `EchoCaveUITests` target and shared `App` scheme with an iOS system accessibility audit.

## Dependencies

Runtime web code remains framework-free. Exact Capacitor and plugin versions are locked in `package-lock.json`; Python Playwright is pinned in `requirements-dev.txt`.

## Browser support

- Native iPhone app: iOS 15+
- iOS Safari 14+ for the standalone web/PWA build
- Desktop Chrome / Safari / Firefox (current)
- Tested cross-device via Playwright; production behavior has been observed on real iPhone

## Known iOS-specific behaviors handled

- AudioContext `interrupted` state recovery on visibility change, focus, touch, click
- Low-vision pinch zoom is permitted; the old forced zoom reset was removed
- HTTP-context Clipboard API fallback (uses `execCommand('copy')` then textarea-select)
- Priority plus on-demand narration with a 48 MiB decoded-audio LRU budget
- Native AVAudioSession interruption recovery and headphone-disconnect pause

## Accessibility

- ARIA dialog + `aria-modal` on every panel
- `aria-label` on every interactive element
- Live regions for status updates (selectively disabled where George duplicates them — see Settings → Diagnostics for current ARIA audit pass count)
- A persistent semantic action surface remains available in Pure Audio mode
- Native accessibility custom actions mirror movement, Listen, Repeat, Teleport, Inventory, and Settings
- Auto Listen Mode after 4 seconds of stillness
- Two-finger tap = teleport home (works without seeing the dpad)
- Double-tap-and-hold = rotor menu (VoiceOver-style action wheel)

## License & ownership

See `LICENSE`. On July 22, 2026, Sulieman Vidal attested that he generated the Echo Cave clips under a paid ElevenLabs subscription represented as commercially usable. A supplied Stripe credit note corroborates the Creator plan at US$22 per month; generation-period coverage and applicable terms remain a documentary release gate in the asset-rights ledger.

Before App Store submission, close every gate in [the release checklist](docs/app-store/release-checklist.md), especially documentary support for the [ElevenLabs paid-plan attestation](docs/app-store/owner-confirmations.md), public privacy/support URLs, blind-player TestFlight sign-off, and an Xcode 26 archive.
