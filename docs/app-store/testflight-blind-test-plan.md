# TestFlight blind-tester plan

Status: Required release gate for Echo Cave 1.0.

## Goal

Demonstrate that blind players can complete every common task on a physical iPhone with VoiceOver and Screen Curtain, without sighted assistance, while the game remains stable, understandable, offline, and recoverable after normal iOS interruptions.

Apple's Accessibility Nutrition Label standard requires all common tasks—not a sample screen—to work with a claimed feature. Apple specifically requires VoiceOver-only completion without sighted assistance. [Accessibility Nutrition Labels overview](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/) and [VoiceOver evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria)

## Cohorts

Recruit **8–12 external blind or low-vision testers** for the release-candidate cycle. Favor depth and device/configuration diversity over an open public link.

Target representation:

- At least 6 testers who use VoiceOver daily.
- At least 2 VoiceOver users who primarily use a paired refreshable braille display.
- A mix of VoiceOver speech rates, including at least 2 high-rate users.
- At least 2 users on a small-screen iPhone.
- At least 2 users on current iOS 26.x hardware/software.
- At least 1 user on the minimum-supported iOS 15.x path. If the current TestFlight client cannot install on that OS, use a development or ad hoc signed build with the same release configuration and record the exception.
- Wired, Bluetooth, and built-in speaker audio routes across the group.
- At least 2 users who enable Mono Audio or have limited stereo discrimination, to verify that speech, text, and control labels remain sufficient.

Do not ask testers to disclose a medical diagnosis. Collect only the assistive-technology, device, OS, audio route, and test observations needed for the product audit. Explain that TestFlight feedback may share identity, device/OS details, screenshots, comments, and crash information with the developer through App Store Connect. [Apple beta tester feedback reference](https://developer.apple.com/help/app-store-connect/reference/testflight/beta-tester-feedback/)

## Distribution rings

| Ring | Audience | Size | Purpose | Promotion gate |
| --- | --- | ---: | --- | --- |
| 0 — Engineering | App Store Connect internal testers | 2–5 | Install, launch, audio, save migration, offline, crash, and network smoke | No open P0/P1; archive matches release configuration |
| 1 — Blind core | Invited external daily VoiceOver users | 4–6 | Moderated common-task and interruption pass | Every core task completed; no sighted-assistance blocker |
| 2 — Blind expanded | Invited external blind/low-vision and braille users | 8–12 total | Device, OS, speech-rate, braille, audio-route, and endurance coverage | Exit criteria met across the full matrix |

Apple permits up to 100 internal App Store Connect users and up to 10,000 external testers, with TestFlight builds available for up to 90 days. External testing requires an internal group first and the first external build goes through TestFlight App Review. [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/) and [invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)

## Build and group setup

- Internal group: `Echo Cave — Engineering`
- External group: `Echo Cave — Blind Accessibility RC`
- Use email invitations for the focused cohort; do not use an unrestricted public link for the release gate.
- Feedback email: `vidalsulieman@gmail.com`
- Enable TestFlight feedback and confirm the email path is usable with VoiceOver.
- Add the copy in [metadata-en-US.md](metadata-en-US.md) as Beta App Description and What to Test.
- Record version, build, Git commit, archive hash, content/audio manifest hash, and release configuration in the test report.
- Reset test observations when a new build changes navigation, audio, save format, onboarding, gestures, or accessibility semantics.

## Device and configuration matrix

Every row is required unless marked exploratory. One tester may cover multiple rows, but each required row needs a named result and evidence.

| ID | Device/OS slot | VoiceOver configuration | Audio route | Required focus |
| --- | --- | --- | --- | --- |
| M1 | iPhone SE (2nd or 3rd generation), iOS 15.x | VoiceOver, Screen Curtain, default rate | Wired or built-in speaker | Minimum OS, small display, low-memory lifecycle |
| M2 | Small-screen supported iPhone, newest compatible iOS | VoiceOver, Screen Curtain, high speech rate | Bluetooth | Dense labels, rapid navigation, route changes |
| M3 | Mid-size iPhone, iOS between minimum and current | VoiceOver, Screen Curtain | Stereo headphones | Representative full common-task pass |
| M4 | Current large-screen iPhone, latest public iOS 26.x | VoiceOver, Screen Curtain | Stereo headphones | Current OS, full regression, App Store capture candidate |
| M5 | Supported iPhone, current iOS | VoiceOver plus paired braille display | Any | Focus, braille labels/values, Unicode cave-map export |
| M6 | Supported iPhone, current iOS | VoiceOver, Screen Curtain, Mono Audio | Built-in speaker or headphones | No core task depends only on stereo separation |
| M7 | Supported iPhone, current iOS | VoiceOver, Screen Curtain | Bluetooth headphones | Connect/disconnect, route switching, interruption recovery |
| M8 | Supported iPhone, current iOS | VoiceOver off; Increase Contrast/Reduce Motion exploratory pass | Any | Sighted/low-vision regression; does not establish label support |

iPad is not version 1 submission scope. Track iPad layout, pointer/keyboard behavior, and no-haptics testing in a post-launch plan before enabling iPad as a supported device family.

## Common-task matrix

Run all rows with VoiceOver and Screen Curtain. “Pass” means completion without sighted assistance, without guessing an unlabeled control, and without a tester being coached through an app-specific workaround.

| ID | Common task | Required observable result | M1 | M2 | M3 | M4 | M5 | M6 | M7 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | Install and first launch | App opens to one logically ordered welcome surface; focus starts meaningfully |  |  |  |  |  |  |  |
| T2 | Complete onboarding | Narration, controls, progress, and Begin are perceivable; no unexplained lockout |  |  |  |  |  |  |  |
| T3 | Listen to a room | Current location and available paths can be requested and repeated |  |  |  |  |  |  |  |
| T4 | Move and reject a wall | Four direction controls are distinct; valid/invalid move result is announced |  |  |  |  |  |  |  |
| T5 | Reach the first exit | First cave can be solved without sight, stereo-only guessing, or custom gesture |  |  |  |  |  |  |  |
| T6 | Descend and navigate a branch | New level state and branch choices are understandable and operable |  |  |  |  |  |  |  |
| T7 | Teleport home | Action is discoverable; result and new location are announced |  |  |  |  |  |  |  |
| T8 | Repeat last narration | Action is discoverable and repeats the correct line without speech collision |  |  |  |  |  |  |  |
| T9 | Use inventory | Open, inspect, use/drop one eligible item, and close with correct focus return |  |  |  |  |  |  |  |
| T10 | Review Journal and Achievements | Counts, entries, locked/earned state, Read Aloud, and close are accessible |  |  |  |  |  |  |  |
| T11 | Change Settings | Toggle narration, haptics, pings, and presentation; values update and persist |  |  |  |  |  |  |  |
| T12 | Open cave map/braille view | Paths have a coherent text/braille alternative; copy/share is operable |  |  |  |  |  |  |  |
| T13 | Play Daily Cave | Enter, distinguish daily state, play, share/cancel, and return to personal cave |  |  |  |  |  |  |  |
| T14 | Background and resume | Location, focus, audio, VoiceOver, and save state recover correctly |  |  |  |  |  |  |  |
| T15 | Handle interruption | Siri/call/alarm pauses and resumes cleanly without overlapping or lost narration |  |  |  |  |  |  |  |
| T16 | Change audio route | Disconnect/reconnect headphones; audio does not vanish, blast, or change direction incorrectly |  |  |  |  |  |  |  |
| T17 | Lock and unlock | Game resumes in a known state with coherent focus and audio session |  |  |  |  |  |  |  |
| T18 | Relaunch offline | Airplane Mode launch works; progress/settings persist; no network error blocks play |  |  |  |  |  |  |  |
| T19 | Recover from destructive action | Reset/erase confirmation names consequences and supports cancel; result is announced |  |  |  |  |  |  |  |
| T20 | Find help/privacy/support | Help is readable; fixed links are labeled; returning to the game restores focus |  |  |  |  |  |  |  |

Record `PASS`, `FAIL`, `BLOCKED`, or `NOT RUN`, plus an issue link. Blank is not a pass.

## Session script for testers

1. Turn on VoiceOver and Screen Curtain before launching.
2. Start from a clean install. Think aloud or record notes only if comfortable.
3. Complete T1–T13 without a sighted person describing the screen or pointing to a control.
4. Complete interruption tasks T14–T18.
5. Complete T19–T20, then play freely for at least 30 minutes to expose fatigue, repeated-speech, memory, and audio-queue problems.
6. Submit the short questionnaire and one issue per distinct failure.

Suggested questions:

- Which task, if any, required sighted help?
- Was any control, value, state, or error unlabeled or ambiguously labeled?
- Did the app narrator and VoiceOver ever speak over one another or leave an important silence?
- Could you tell which paths were available without relying only on stereo position?
- Could you recover after getting lost, interrupting audio, or returning later?
- Did focus ever leave an open sheet, land behind it, disappear, or return unpredictably?
- Was any required custom gesture difficult or in conflict with VoiceOver?
- What was tiring, repetitive, too loud, too quiet, or too slow?
- Would you independently describe the first cave, inventory, settings, journal, and daily mode to another blind player? What would be confusing?

## Issue severity

| Severity | Definition | Examples | Release effect |
| --- | --- | --- | --- |
| P0 | Crash, data loss, unsafe audio behavior, or complete loss of control | Launch crash; save erased; maximum-volume burst; no way to stop audio | Stop testing; fix immediately |
| P1 | A blind player cannot complete a common task without sighted help | Unreachable Begin; unlabeled direction; trapped focus; stereo-only required route | Blocks release and VoiceOver claim |
| P2 | Task completes but with serious confusion, repetition, or unreliable workaround | Wrong focus return; duplicate narration; route change needs restart | Fix before release unless product owner documents and accepts narrow residual risk |
| P3 | Minor polish issue with no task impact | Slightly verbose hint; harmless announcement timing | May defer with owner and accessibility reviewer sign-off |

## Entry criteria

- [ ] Release configuration installs and launches on M1 and M4.
- [ ] All required audio is bundled and rights-cleared for TestFlight distribution.
- [ ] Automated game-core, storage, audio-manifest, accessibility identifier, and UI smoke tests pass.
- [ ] No known P0 or P1 bug is open.
- [ ] Network audit shows no unintended traffic.
- [ ] Privacy/support/accessibility drafts are reachable from the build or a reviewer-accessible test URL.
- [ ] Testers received the privacy explanation and accessible feedback instructions.

## Exit criteria

- [ ] Every T1–T20 row passes on M3 and M4.
- [ ] Every applicable row passes on the minimum-OS/small-screen M1 slot.
- [ ] T1–T13 and T18–T20 pass with braille on M5.
- [ ] T1–T13 and T18 pass with Mono Audio on M6 without a stereo-only blocker.
- [ ] T14–T18 pass on M7.
- [ ] Every blind tester completes onboarding and reaches an exit without sighted help.
- [ ] No open P0, P1, or unaccepted P2 issue remains.
- [ ] Zero unexpected network requests are observed in the final candidate.
- [ ] At least 8 external blind/low-vision testers completed the release-candidate build.
- [ ] The product owner and a blind accessibility reviewer sign the final report.
- [ ] Only after all above: approve the VoiceOver product-page claim and save the iPhone Accessibility Nutrition Label draft.

## Final report

| Field | Result |
| --- | --- |
| App version/build |  |
| Commit and archive hash |  |
| Test dates |  |
| Testers completed |  |
| Device/OS rows completed |  |
| Common-task pass rate |  |
| Open P0 / P1 / P2 / P3 |  |
| Network audit result |  |
| VoiceOver claim approved by |  |
| Blind accessibility reviewer |  |
| Product owner |  |
