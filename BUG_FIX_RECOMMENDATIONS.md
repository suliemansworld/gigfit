# Echo Cave Bug Fix Recommendations

_Last reviewed: 2026-05-23_

## Highest priority

1. **Fix service worker cache updates**
   - `index.html` is currently on build `20260523a`, while `sw.js` still declares `BUILD = '20260519a'`.
   - The service worker also serves cached assets before checking the network, including `index.html`.
   - Recommended fix: bump the service worker build tag with every deploy and make navigations / `index.html` network-first so players do not get stuck on stale game builds.

2. **Move the working tests into this repo**
   - `package.json` points `npm test` at `~/test_echo_game.py` and `~/test_echo_game_e2e.py`, but those files are not in the GitHub repo.
   - Recommended fix: add the current Playwright scripts under `tests/` and update `package.json` to run them from repo-relative paths.

3. **Refresh the README**
   - The README explains the game well, but some facts are stale: line count, voice corpus count, build line number, and test paths.
   - Recommended fix: update the README so a fresh GitHub visitor can understand, run, and validate the project without local-only context.

## Medium priority

4. **Replace native browser confirms**
   - Descend and reset actions use `confirm()`.
   - They work, but they break the audio-first interaction model and are harder to narrate consistently.
   - Recommended fix: use custom in-game confirmation panels with George narration, keyboard support, and clear focus handling.

5. **Add a service worker deploy checklist**
   - The app depends on aggressive cache busting for iOS Safari.
   - Recommended fix: document the required deploy steps: bump `window.ECHO_BUILD`, bump `sw.js` `BUILD`, verify `/echo-game/` and `/echo-game/sw.js`, then run the smoke tests.

6. **Clean up stale handoff notes**
   - `HANDOFF_2026-04-28.md` is useful history, but it references old build numbers and old local test paths.
   - Recommended fix: either archive it as historical context or add a top note pointing readers to the current README and current tests.

## Product polish

7. **Add a recent-events rotor entry**
   - Helps blind players recover context after interruptions.
   - It could read the last room, last blocked path, last loot, last achievement, and last journal event.

8. **Add adjustable gesture timing**
   - Double-tap-and-hold timing should be configurable for motor accessibility.
   - Suggested presets: fast, normal, relaxed.

9. **Add a short guided demo cave**
   - A 60-second fixed-path demo would make the audio-first concept easier to understand before the procedural game starts.

10. **Make the journal more central**
    - The journal is a strong hook for retention.
    - Recommended fix: surface lore beats more intentionally after milestones and descents, especially when returning to the game.

## Validation target

Before sharing publicly, the repo should support:

```bash
npm test
```

Expected coverage:

- Fresh onboarding flow
- Touch and keyboard movement
- Inventory, settings, achievements, journal, and map panels
- Service worker registration without console errors
- Exit reach, Stage 2 unlock, descent, and reset flows
- Rotor open / advance / close gestures

