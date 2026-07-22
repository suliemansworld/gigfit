# Echo Cave accessibility

Status: Public pre-release accessibility statement. Do not add its URL to App Store Connect until the verification gates are complete.

## Our approach

Echo Cave is an audio-first cave exploration game created with blind players at its heart. The goal is not simply to make a visual game readable by a screen reader: sound, speech, touch, and optional haptics are the primary way the cave communicates.

Version 1 is an iPhone app. It is designed so a player can complete onboarding, explore, reach an exit, descend, manage items, review the journal and achievements, change settings, play a Daily Cave, and recover after an interruption without sighted assistance.

## VoiceOver

The release target provides:

- Concise labels, values, traits, and hints for every interactive control.
- Standard VoiceOver focus and activation for movement, Listen, Repeat Narration, Menu, Teleport Home, inventory actions, settings, and dialogs.
- Accessible alternatives for every custom swipe, multi-touch, hold, drag, or directional game gesture.
- Logical focus order, modal focus containment, Escape dismissal where appropriate, and focus restoration when a panel closes.
- Spoken and braille-readable status for room changes, available paths, discoveries, errors, achievements, and save state.
- Full common-task play while Screen Curtain is on.

Optional game gestures are shortcuts, not accessibility requirements. When VoiceOver is running, players can use familiar VoiceOver navigation and the app's labeled controls or accessibility actions.

Apple's VoiceOver label requires all common tasks to work using VoiceOver alone, without sighted assistance. Echo Cave will not claim that label until the blind-tester exit gate passes on physical iPhones. [Apple VoiceOver evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria)

## Audio and haptics

- Spoken narration describes the cave, story, discoveries, and game state.
- Directional pings and ambience help identify paths and landmarks. Stereo headphones are recommended for the clearest left/right distinction, but labeled controls and spoken state must keep tasks available without stereo hearing.
- Listen and Repeat Narration let players request information again.
- Haptics are optional and never the only way information is communicated.
- The game must recover after Siri, calls, alarms, route changes, headphone disconnection, locking, and backgrounding without losing progress.

For safety, play at a comfortable volume and remain aware of your surroundings. Do not rely on game audio while driving or when attention to environmental sound is important.

## Visual access

- Version 1 uses a dark interface.
- Important state is not conveyed by color alone.
- Visible controls and text remain available for sighted and low-vision players; audio-only presentation is optional.
- Claims for Larger Text, Sufficient Contrast, Reduced Motion, and Voice Control will be added only after their full common-task audits pass.

## Deaf, hard-of-hearing, and DeafBlind access

Controls and key status are exposed as text and VoiceOver/braille output. However, Echo Cave's environmental soundscape is central to play, and version 1 does not yet claim Apple's Captions label for every meaningful nonverbal sound. Feedback about missing text or tactile equivalents is especially welcome.

## Braille

VoiceOver output is available to a paired braille display through iOS. The in-game cave-map export uses Unicode braille patterns and Grade 1 English; it is a supplemental representation, not a replacement for labeled navigation controls. Braille-display users are included in the TestFlight matrix.

## Known scope

- Version 1 supports iPhone only.
- iPad is planned as a separate post-launch evaluation, including layouts and a no-haptics path.
- The clearest spatial presentation uses stereo headphones.
- Accessibility claims apply to the version and device family explicitly tested; they are reviewed again for every update.

## Feedback

If anything requires sighted assistance, if VoiceOver focus becomes trapped or escapes a dialog, or if a sound cue lacks an understandable alternative, email [vidalsulieman@gmail.com](mailto:vidalsulieman@gmail.com).

Please include the Echo Cave version/build, iPhone model, iOS version, VoiceOver and Screen Curtain state, audio output, what you expected, and what happened. Do not include sensitive personal information.

Last updated: July 22, 2026
