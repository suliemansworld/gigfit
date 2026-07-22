# App Store metadata — English (U.S.)

Status: Copy-ready draft for Echo Cave 1.0. Recheck every claim against the selected release build immediately before submission.

Apple currently limits the app name to 30 characters, subtitle to 30 characters, promotional text to 170 characters, description to 4,000 characters, and keywords to 100 bytes. [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information) and [platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)

## Shared app information

| Field | Value | Size |
| --- | --- | ---: |
| App name | `Echo Cave` | 9 characters |
| Subtitle | `An audio-first adventure` | 24 characters |
| Primary language | English (U.S.) | — |
| Primary category | Games | — |
| Games subcategory | Adventure | — |
| Secondary category | None for 1.0 | — |
| Copyright | `2026 Sulieman Vidal` | Apple adds the copyright symbol |
| Made for Kids | No | — |
| Age category override | Not Applicable | — |

Do not reserve a Bundle ID or SKU from this document without checking the Xcode project and Apple Developer account. Apple makes the Bundle ID immutable after a build is uploaded and the SKU immutable after the app record is created. [Apple app information reference](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)

## Promotional text

145 UTF-8 bytes:

```text
Explore a living cave through spatial sound, spoken narration, and haptics. Designed with blind players at its heart—and welcoming to everyone.
```

## Description

```text
Put on your headphones and step into the dark.

Echo Cave is an audio-first exploration game built with blind players at its heart. Listen for the shape of each chamber, follow directional pings, and choose your path through a cave that changes every time you enter.

Your first journey teaches the cave's language one step at a time. Then the passages branch, secrets appear, and every descent takes you deeper. Spoken narration, stereo sound, optional haptics, and fully labeled controls provide multiple ways to understand and control the adventure.

EXPLORE BY EAR
• Hear doors and landmarks around you through directional audio.
• Tap Listen whenever you want to repeat your surroundings.
• Use standard on-screen controls, VoiceOver, or optional game gestures.
• Teleport home if you lose your way.

A CAVE THAT KEEPS CHANGING
• Procedurally generated routes make each cave different.
• Descend through new levels with wider chambers and branching paths.
• Take on a fresh Daily Cave and share your result.

DISCOVER WHAT WAS LEFT BEHIND
• Find compass fragments, echo stones, coins, and other tools.
• Unlock achievements as you explore.
• Piece together the cave's story in your journal.

ACCESSIBILITY AT THE CENTER
• Built around VoiceOver and Screen Curtain testing.
• Spoken narration and accessible alternatives for custom gestures.
• Optional haptics, audio-only presentation, and adjustable sound cues.
• Visual controls and cave information remain available for sighted and low-vision players.

Echo Cave has no ads, no in-app purchases, and no account. Your progress is stored on your iPhone, and the complete game can be played offline.

Headphones are recommended for the clearest sense of direction.
```

The accessibility paragraph must remain unpublished until the VoiceOver exit gate in the blind-tester plan passes. If a feature does not ship, delete its claim rather than describing future work.

## Keywords

92 UTF-8 bytes; does not repeat the app name or developer name:

```text
audio game,blind,low vision,accessible,spatial sound,adventure,exploration,offline,VoiceOver
```

Apple says keywords must be more than two characters each, are limited to 100 bytes, and should not repeat the app or company name or include other app/company names. [Apple platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)

## URLs

| Field | Value for submission |
| --- | --- |
| Privacy Policy URL | `https://echo-cave.suliemanhaidari.chatgpt.site/privacy` |
| Support URL | `https://echo-cave.suliemanhaidari.chatgpt.site/support` |
| Marketing URL | Optional; use the public Echo Cave product site only after it accurately matches 1.0. |
| Accessibility URL | `https://echo-cave.suliemanhaidari.chatgpt.site/accessibility` — public pre-release statement; add to App Store Connect only after the verification gates pass. |

A privacy-policy URL is required for iOS. The support URL must lead to real contact information, and the full URL including `https://` must be supplied. [Apple app information reference](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information) and [platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)

## Version information

| Field | Value |
| --- | --- |
| Version | `1.0` |
| Release method | Manual release recommended for the first version |
| What's New | Not shown for the first version |
| App Review notes | Use [app-review-notes.md](app-review-notes.md) |
| Sign-in required | No |
| In-app purchases | None |

## TestFlight metadata

### Beta app description

```text
Echo Cave is an offline, audio-first cave exploration game designed with blind players at its heart. Use spoken narration, directional sound, accessible controls, and optional haptics to explore procedural caves, collect tools, reach the exit, and descend deeper.
```

### What to Test

```text
Please test with VoiceOver and Screen Curtain on. Complete onboarding, reach the first exit, descend, use Listen and Repeat, teleport home, use one inventory item, open Settings, Journal, Achievements, and Daily Cave, then relaunch offline. Report any task that needs sighted help, any missing or duplicate speech, unclear direction cue, VoiceOver focus escape, gesture conflict, audio interruption failure, lost save, crash, or unexpected network activity.
```

### Feedback email

`vidalsulieman@gmail.com`

External TestFlight distribution requires a beta description, feedback email, and test information. [Provide TestFlight test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/)
