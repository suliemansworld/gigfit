# Screenshot and app-preview plan

Status: Production brief for iPhone-only version 1. Capture from the exact release candidate after all audio rights and metadata claims are cleared.

## Delivery specifications

### Screenshots

- Deliver eight portrait PNG screenshots with no alpha channel.
- Capture the 6.9-inch iPhone layout at an Apple-accepted portrait size. Preferred working size: **1290 × 2796 pixels**. Apple's current 6.9-inch accepted portrait sizes also include 1260 × 2736 and 1320 × 2868 pixels.
- App Store Connect accepts one to ten screenshots. Highest-resolution screenshots can scale to smaller iPhone sizes when the interface is the same.
- Do not submit iPad screenshots for version 1; the Xcode target is iPhone-only.
- Show real in-app use. Do not make the set mostly title, splash, or marketing art.
- Keep the status bar, device state, app version, and content clean of personal information, debug overlays, network addresses, or unfinished material.

[Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) and [App Review Guidelines 2.3.3](https://developer.apple.com/app-store/review/guidelines/)

### App preview

The preview is optional. If produced, deliver one portrait H.264 video at **886 × 1920 pixels**, 15–30 seconds, at no more than 30 fps, with stereo 256 kbps AAC audio at 44.1 or 48 kHz. Apple's limit is 500 MB.

Use only screen capture of the app itself. Text overlays and narration may explain interaction, but footage and transitions must not imply functionality the app lacks. App previews autoplay muted by default, so every spoken line and meaningful sound in the preview needs concise, readable on-screen text.

[Apple app-preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications) and [Apple app-preview guidance](https://developer.apple.com/app-store/app-previews/)

## Accessible media rules

- The “Accessible description” below is source copy for the public marketing page, press kit, review archive, and any content-management system that supports alternative text. Keep it with the asset even if an upload surface does not expose a separate alt-text field.
- Use short overlay headlines, high contrast, generous safe margins, and type large enough to read on a small product-page card.
- Do not put essential product facts only inside an image. Repeat them in the App Store description and accessible website text.
- Do not use color alone to explain direction, success, errors, selection, or progress.
- Caption app-preview narration and meaningful non-speech audio such as directional pings, wind, chimes, and haptics represented visually.
- Avoid rapid flashes, fast zooms, simulated camera shake, and unnecessary motion.
- Do not capture Screen Curtain as a black screenshot. Demonstrate blind access with real labeled controls, VoiceOver focus, and copy that accurately describes the tested experience.
- Do not use any pending-rights narration, music, or sound in screenshots, poster frames, or previews. Marketing use is part of the rights clearance.

## Screenshot sequence

The first three assets should explain the core experience without requiring the viewer to inspect the full set.

| Order | Overlay headline | Release-candidate state to capture | Accessible description |
| ---: | --- | --- | --- |
| 1 | `Explore a cave through sound` | Active cave screen after onboarding, with Listen and movement controls visible and a room status announcement present | Echo Cave's dark gameplay screen on iPhone, showing labeled movement and Listen controls while spoken and directional audio describes a cave chamber. |
| 2 | `Built to play without sight` | Accessibility or Settings screen with spoken narration, haptics, audio-only presentation, and gesture alternatives visible | Echo Cave settings on iPhone, with options for spoken narration, haptic feedback, audio-only presentation, and accessible controls. |
| 3 | `Listen. Choose. Move.` | A room with more than one valid route, after Listen reports the available directions | A branching cave room with Move Forward, Move Left, Move Right, Teleport Home, and Listen controls, showing that every direction has a labeled action. |
| 4 | `A new cave every time` | Cave map from a generated multi-branch level, with player, base, route, and exit states represented without color alone | An accessible map of a procedurally generated cave with several connected chambers, the player's location, the base, and explored routes. |
| 5 | `Find tools in the dark` | Inventory containing at least a compass fragment and echo stone, with usable action labels | The inventory screen listing discovered cave tools such as a compass fragment and echo stone, each with a clearly labeled action. |
| 6 | `Reach the exit. Descend deeper.` | Exit-reached state with the next-level action visible; no spoiler-heavy journal text | The game announcing that the cave exit has been reached and offering a button to descend into a deeper, more complex level. |
| 7 | `Piece together the story` | Journal with two or three entries and a Read Aloud action | The Echo Cave journal showing story fragments discovered during exploration and a button to read the entries aloud. |
| 8 | `A fresh Daily Cave` | Daily Cave result/status screen with share action visible but no personal destination or contact | A Daily Cave summary showing the current day, exploration result, move count, and a user-initiated Share Result button. |

## App-preview storyboard

Target runtime: 27 seconds. Select a poster frame around 5 seconds that shows actual cave play and the overlay “Explore a cave through sound.”

| Time | Footage | On-screen text and accessible caption | Audio |
| --- | --- | --- | --- |
| 0–3 s | Launch directly into a clean in-app welcome transition | `Put on your headphones. Step into the dark.` | Cleared cave ambience fades in. |
| 3–7 s | First cave room; VoiceOver focus moves across Listen and movement controls | `Built to play without sight` | Cleared narrator line; caption it verbatim. |
| 7–13 s | Activate Listen, then take a left or right route | `Listen. Choose. Move.` plus `[directional ping: left]` | Preserve stereo cue and caption its direction. |
| 13–17 s | Find and open an inventory item | `Discover tools and hidden stories` | Cleared discovery chime with `[discovery chime]`. |
| 17–22 s | Reach the exit and activate Descend | `Every descent changes the cave` | Cleared exit cue and narration, captioned. |
| 22–27 s | Quick dissolve through Journal and Daily Cave, ending on active gameplay | `Echo Cave — an audio-first adventure` | Resolve to the cleared Echo Cave sonic mark; no unrelated licensed music. |

## Capture checklist

- [ ] Asset rights are `APPROVED`, including marketing use in all release territories.
- [ ] The exact App Store build and final production data are installed.
- [ ] No debug menus, diagnostics, Live Link, test seeds, IP addresses, or accessibility-development labels are visible.
- [ ] Screenshot states are reachable by normal player actions and contain no fabricated features.
- [ ] All eight screenshot overlays match the product description and final UI.
- [ ] Text remains inside safe margins and readable at thumbnail size.
- [ ] VoiceOver pronunciations and captions in the preview match actual audio.
- [ ] Preview makes sense muted from beginning to end.
- [ ] Preview remains understandable with audio only, without relying on visual copy for a gameplay step.
- [ ] Screenshots are PNG/JPEG without alpha; preview passes Apple's codec, resolution, frame-rate, duration, and file-size checks.
- [ ] Files are named by locale, display size, and order, for example `en-US_iPhone-6.9_01_explore.png`.
- [ ] Final accessible descriptions are published next to the media on the public marketing/accessibility site.
