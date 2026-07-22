# App Review notes

Use the copy-ready block below in App Store Connect after checking every control name against the selected build. Apple allows up to 4,000 bytes in the Notes field and asks developers to include information needed to test the app. [Apple platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)

## Copy-ready notes

```text
Echo Cave is an offline, audio-first exploration game designed to be fully playable by blind players. There is no account, login, demo account, backend, advertising, analytics, tracking, in-app purchase, or subscription.

HEADPHONES
Stereo headphones are recommended so left/right directional cues are easiest to distinguish, but they are not required. Please allow the onboarding narration to finish before beginning the first cave.

FAST REVIEW PATH
1. Launch Echo Cave and activate “Enter Echo Cave.”
2. Listen to the short introduction and tutorial, then activate “Begin.”
3. Activate “Listen” to hear the current room and available direction.
4. The first cave is intentionally a straight teaching path. Repeatedly activate “Move forward,” using “Listen” whenever desired, until the exit is announced.
5. Activate “Descend” to demonstrate procedural continuation and branching routes.
6. Open “Menu” to inspect Inventory, Journal, Achievements, Daily Cave, Settings, Repeat Narration, and Teleport Home. No feature requires network access.

VOICEOVER REVIEW PATH
1. Enable VoiceOver in iOS Settings or with the Accessibility Shortcut.
2. Relaunch Echo Cave. Swipe through the welcome screen and activate “Enter Echo Cave” with the standard VoiceOver double-tap.
3. Complete the Fast Review Path using the labeled on-screen controls. Every common action exposed by an optional game gesture is also available as a standard control or accessibility action; the game does not require its custom swipe or hold gestures while VoiceOver is running.
4. Optional: turn on Screen Curtain with a three-finger triple-tap. The onboarding, first exit, inventory, settings, journal, achievements, and return path remain usable without sight.

The in-game narrator communicates cave state and story. VoiceOver communicates control labels, values, and navigation. Narration can be adjusted in Settings. Focus is constrained to an open sheet or dialog and returns to the initiating control when it closes.

NATIVE iOS FUNCTIONALITY
The iPhone build includes bundled offline content, native storage, native haptics, audio-session interruption recovery, iOS sharing for a user-initiated Daily Cave result, and VoiceOver-accessible controls/actions. The procedural cave, persistent progression, daily mode, inventory, journal, and achievements provide replayable game content.

PRIVACY AND DIAGNOSTICS
Game progress and settings are stored only on the device. The App Store build contains no remote logging endpoint. Its diagnostics are local-only and do not transmit data. The optional web prototype “Live Link” is not present in this archive.

No special hardware, account, purchase, location, camera, microphone, contacts, Bluetooth permission, or notification permission is required.

Contact: vidalsulieman@gmail.com
```

## Reviewer-path preflight

- [ ] The quoted labels exist exactly as written in the release archive.
- [ ] A clean install can reach the first exit by following the steps above.
- [ ] The tutorial has no unexplained wait longer than the narration itself.
- [ ] VoiceOver focus enters and leaves every presented sheet correctly.
- [ ] Screen Curtain does not pause or mute the game.
- [ ] The app works in Airplane Mode after installation.
- [ ] A packet capture confirms that diagnostics and error paths transmit nothing.
- [ ] Every listed feature is visible and functional; remove anything that is not in the submitted build.
- [ ] The support, privacy, and accessibility URLs are public and working without authentication.

These notes intentionally explain the native, lasting game experience because Apple says an app should go beyond a repackaged website under Guideline 4.2. They must describe the actual archive, not planned work. [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
