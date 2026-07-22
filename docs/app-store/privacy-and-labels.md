# Privacy and App Store labels

Status: Draft answers for an **offline, no-data App Store archive**. Do not publish these answers until the release gates below pass.

Apple requires App Privacy answers to cover the developer's practices and those of integrated third parties across every platform for the app. The answers must stay accurate as practices change. [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)

## Mandatory no-data release gates

- [x] Diagnostics “Live Link” and `/diag/` requests were removed on July 22, 2026; no analytics or crash-reporting SDK is included.
- [ ] Bundle all narration, ambience, effects, configuration, and game content required for play.
- [ ] Run a release-archive network audit through launch, onboarding, new game, daily game, sharing cancellation, diagnostics, background/foreground, relaunch, corrupted-save recovery, and failed audio lookup.
- [ ] Confirm there is no WebView navigation to the old HTTP demo, no remote asset fallback, and no invisible web request.
- [ ] Inventory all Apple and third-party SDKs in the final archive and reconcile their behavior and privacy manifests.
- [ ] Confirm the share sheet is user initiated and that Echo Cave neither receives nor stores the selected destination or post-send result.
- [ ] Confirm support and privacy links open only when the player chooses them; disclose any in-app support form if one is later added.
- [ ] Have the release owner sign and date this page after comparing it with the exact uploaded build.

If any gate fails, do **not** choose “Data Not Collected.” Update both the answers and `PRIVACY.md` to disclose the actual data types, purposes, linkage, and tracking behavior.

## App Privacy Nutrition Label draft

In App Store Connect → App Privacy:

| Question | Draft answer | Basis |
| --- | --- | --- |
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app** | Release-gated: all game data stays on the device and the archive contains no telemetry or third-party collection. |
| Tracking | **No** | No advertising identifier, cross-app/site linkage, data broker, or targeted advertising. |
| Data linked to the user | **None** | No account or transmitted identifier. |
| Data not linked to the user | **None** | No analytics, diagnostics, usage, crash, or gameplay event transmission by the app/developer. |

Apple defines “collect” as transmitting data off the device in a form the developer or a partner can access for longer than needed to service the request in real time. It separately confirms that data processed only on-device is not collected. Apple directs developers who collect nothing to choose “No, we do not collect data from this app,” after which no data-type questions are required. [Apple's App Privacy details](https://developer.apple.com/app-store/app-privacy-details/) and [App Privacy workflow](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)

### Important boundaries

- Apple's own App Store and TestFlight processing is governed by Apple; do not describe it as Echo Cave analytics. TestFlight feedback can include tester identity, device, OS, screenshots, comments, and crash information in App Store Connect. Tell beta testers this before they submit feedback. [Apple TestFlight feedback reference](https://developer.apple.com/help/app-store-connect/reference/testflight/beta-tester-feedback/)
- Email sent voluntarily through the external Mail app is handled as described in `PRIVACY.md`. A future in-app support form or SDK must be reassessed. Apple allows optional disclosure for infrequent, user-initiated support collection only when every criterion in its optional-disclosure rule is met; otherwise disclose Customer Support and any related contact/user-content types.
- A user-selected Daily Cave share leaves through the system share sheet. Echo Cave must not log the destination, contents, completion, or recipient.
- Local diagnostics may show build, audio, and accessibility state on the device. Any transmission changes the analysis and must be disclosed before release.

## Accessibility Nutrition Labels draft

Apple's Accessibility Nutrition Labels apply per device family. A feature may be claimed only when people can complete **all common tasks** using that feature. [Accessibility Nutrition Labels overview](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/)

For iPhone version 1, save the following as a draft only after the relevant verification row passes:

| Label | Draft selection | Evidence required before selection |
| --- | --- | --- |
| VoiceOver | **Supports — release candidate** | Every common-task row in the blind-tester matrix passes using only VoiceOver, with Screen Curtain, without sighted assistance. |
| Dark Interface | **Supports — release candidate** | Every screen, sheet, alert, onboarding state, and error state uses the complete dark appearance without an unthemed flash or unreadable system surface. |
| Differentiate Without Color Alone | **Supports — release candidate** | Direction, validity, progress, state, achievement, selection, and errors are conveyed by text, speech, sound, shape, or state—not color alone. |
| Sufficient Contrast | Do not indicate yet | Requires measured contrast and physical-device review for all text, icons, controls, disabled states, and overlays. |
| Reduced Motion | Do not indicate yet | Requires all common tasks to honor Reduce Motion and a verified alternative to cave/intro motion. |
| Larger Text | Do not indicate yet | Requires all common tasks at 200% or more text size with no clipped, hidden, or unreachable controls. |
| Voice Control | Do not indicate yet | Requires a complete Voice Control common-task audit, including unique spoken names and non-gesture alternatives. |
| Captions | Do not indicate | Core environmental audio and nonverbal cues do not yet have verified time-synchronized text equivalents meeting Apple's criteria. |
| Audio Descriptions | Do not indicate | The app has no video program requiring time-synchronized audio description. |

Apple says published accessibility information may take up to 24 hours to appear and currently allows support to be published only for a device family with a live app version. Prepare the draft before launch, publish verified labels after 1.0 is live, and publish the Accessibility URL with the first release. [Manage Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels)

## Sign-off

| Item | Value |
| --- | --- |
| App version/build audited |  |
| Archive hash |  |
| Network-audit method and evidence link |  |
| Dependency/SDK inventory evidence |  |
| Privacy manifest review |  |
| Reviewer |  |
| Date |  |
| Final App Privacy answer |  |
| Accessibility draft saved |  |
