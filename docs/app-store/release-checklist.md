# Echo Cave 1.0 release checklist

Use this checklist against one immutable release candidate. Record evidence links or hashes beside each completed gate; a checked box without evidence is not sufficient for rights, privacy, accessibility, or archive verification.

## 1. Ownership, account, and scope

- [ ] Apple Developer Program membership is active and the Account Holder has accepted current agreements.
- [ ] App Store Connect users have only the roles needed for build upload, TestFlight, metadata, review, and release.
- [x] Version 1 scope is documented as iPhone only; Xcode `TARGETED_DEVICE_FAMILY` is `1` and no iPad screenshots or accessibility claims are submitted.
- [x] Minimum deployment target is iOS 15.0.
- [ ] App name availability is confirmed before creating the app record.
- [x] Product owner confirmed bundle ID `com.suliemansworld.echocave`, and it exactly matches Xcode. Reconfirm uniqueness while creating the App Store record; it cannot be changed after a build is uploaded.
- [ ] SKU is final before the app record is created; it cannot be changed later.
- [ ] Primary language is English (U.S.); primary category is Games and subcategory is Adventure.
- [ ] Distribution countries/regions are intentionally selected and any local regulatory requirements are reviewed.
- [ ] Digital Services Act trader/non-trader status and any required public contact information are completed by the Account Holder.
- [ ] Price is an explicit product-owner decision; metadata remains accurate whether the app is free or paid.
- [ ] Tax and banking agreements are complete if the app is paid.

Apple's app-information reference identifies immutable Bundle ID/SKU fields, required content rights, age rating, categories, and privacy-policy URL. [Apple app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)

## 2. Content and asset rights

- [ ] Every shipping asset appears in [asset-rights-ledger.md](asset-rights-ledger.md).
- [x] Product owner's July 22, 2026 paid-plan ElevenLabs attestation is recorded in [owner-confirmations.md](owner-confirmations.md).
- [x] Owner-supplied June 16, 2026 Stripe credit note corroborates an ElevenLabs Creator subscription at US$22/month; the sensitive image remains outside Git and its SHA-256 is recorded.
- [x] Owner-supplied July 22, 2026 API request log was reviewed and fingerprinted outside Git; it shows successful subscription/usage interface requests but contains no response payloads or historical clip-generation dates, so it does not close the coverage gate.
- [ ] The associated invoice/account history confirms Creator-plan coverage on the generation dates, and generation history plus applicable terms have been archived and reviewed for all 79 MP3 outputs.
- [ ] If historical evidence is insufficient and regeneration is used, replacement hashes prove none of the superseded originals remain in the app archive, asset catalog, copy bundle, test fixture, screenshot, or preview.
- [ ] All 610 referenced narration WAV files have generation dates, plan/tier evidence, voice/model terms, and commercial-use approval; the 3 unreferenced legacy WAVs remain excluded from the build.
- [ ] All music, ambience, sound effects, footsteps, friction, and loop assets have provenance and commercial app/marketing rights.
- [ ] App icon, screenshots, preview, fonts, story text, and third-party code are approved.
- [ ] Attribution and license-notice obligations are implemented in-app and/or on the support site as required.
- [ ] Final ledger contains no `BLOCKED` or `PENDING` asset used by the archive.
- [ ] App Store Connect Content Rights answer matches the signed ledger.

## 3. Production privacy gate

- [x] Diagnostics “Live Link,” `/diag/` requests, remote asset fallbacks, telemetry, analytics, and remote logging are absent from source and dependencies.
- [ ] No analytics, advertising, crash-reporting, tracking, identity, or remote-config SDK is linked.
- [ ] All game assets and configuration needed for ordinary and error-path play are bundled.
- [ ] No old HTTP demo URL, development server, IP address, staging endpoint, API key, token, or credential appears in the binary or resources.
- [ ] Release archive is exercised behind a recording proxy/DNS logger through all flows in [privacy-and-labels.md](privacy-and-labels.md); result is zero unexpected requests.
- [ ] Airplane Mode clean launch, new game, saved game, Daily Cave, diagnostics, and relaunch all work.
- [ ] Daily-result share sheet is user initiated; cancel and complete paths reveal no destination/result to the app.
- [ ] Dependency and SDK inventory is saved with the release evidence.
- [ ] App privacy manifests and required-reason API declarations, if applicable to the final code and dependencies, are validated in the uploaded archive.
- [ ] `PRIVACY.md` matches actual code, linked SDKs, support flow, retention, and deletion behavior.
- [x] Privacy policy is reachable at `https://echo-cave.suliemanhaidari.chatgpt.site/privacy` without sign-in and from an easy-to-find in-app link.
- [ ] App Privacy answer is published as “No, we do not collect data from this app” only after the privacy sign-off is complete.

Apple requires a privacy-policy link in App Store Connect and inside the app, with clear collection, sharing, retention/deletion, and consent information. [App Review Guideline 5.1.1](https://developer.apple.com/app-store/review/guidelines/) and [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)

## 4. Build and archive

- [ ] Use Xcode 26 or later with an iOS 26 SDK or later. Apple has required this for uploads since April 28, 2026. [Apple upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)
- [ ] Build on a supported macOS host. Xcode 26 requires macOS Sequoia 15.6 or later; verify the exact selected Xcode version against [Apple's current Xcode system requirements](https://developer.apple.com/xcode/system-requirements/).
- [x] Xcode app and UI-test targets preselect Apple Team `36R3VCWWUJ`, as identified by the installed signing identities and Xcode-managed profiles.
- [ ] Release configuration resolves an Echo Cave distribution profile for Apple Team `36R3VCWWUJ`, the final Bundle ID, and intended entitlements only; validate this on the Xcode 26 archive host.
- [ ] Marketing version is `1.0`; build number is unique and increasing.
- [ ] Deployment target is iOS 15.0 and Supported Destinations is iPhone only.
- [ ] App icon set is complete, opaque where required, and renders correctly in light/dark/tinted system contexts where applicable.
- [ ] Display name is `Echo Cave` and no placeholder product/module name appears on device.
- [ ] Launch experience has no blank, web-server, or debug screen and becomes VoiceOver-ready immediately.
- [ ] All required audio appears in Copy Bundle Resources exactly once; obsolete duplicate formats are intentionally excluded.
- [ ] Release archive size and on-device installed size are reviewed; audio decoding/streaming stays within tested memory limits.
- [ ] App Transport Security exceptions, background modes, microphone, location, camera, contacts, Bluetooth, notifications, and other capabilities are absent unless used and documented.
- [ ] Export-compliance answers match the actual encryption use. Set `ITSAppUsesNonExemptEncryption` only after the signing owner confirms the correct determination. Apple requires an encryption determination for each version. [Apple export-compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)
- [ ] Archive validation passes with no actionable warning.
- [ ] The exact `.xcarchive`, dSYM, export/options record, commit, dependency state, and asset manifest/hash are retained.

## 5. Functional and resilience QA

- [ ] Deterministic game-core tests cover cave generation, reachability, daily seed/date handling, movement, inventory, achievements, journal, descent, reset, and save migration.
- [ ] Audio-manifest validation proves every reference resolves, format decodes on iOS 15 and iOS 26, and no unreferenced prohibited asset ships.
- [ ] Unit and UI tests run in Release-equivalent configuration.
- [ ] Clean install, upgrade from every supported prior save schema, reinstall, low-storage failure, and corrupted-save recovery are tested.
- [ ] First cave is always completable and the review path in [app-review-notes.md](app-review-notes.md) is deterministic.
- [ ] App survives 60 minutes of continuous exploration without growing audio/memory usage, excessive heat, or battery drain.
- [ ] Background/foreground, lock/unlock, Siri, alarm, phone/FaceTime call, Control Center, and audio-route changes recover cleanly.
- [ ] Wired, Bluetooth, speaker, Mono Audio, and volume changes are tested; no route produces a volume burst.
- [ ] VoiceOver speech and app narration do not deadlock, cancel critical information, or layer unintelligibly.
- [ ] Haptics are optional, follow system capability, and are never the sole cue.
- [ ] Portrait layout works on small and large supported iPhones with safe areas and no unreachable control.
- [ ] Offline behavior and date rollover for Daily Cave are tested across time zones and midnight.
- [ ] Destructive actions have accessible confirmation, cancel, accurate consequences, and post-action announcement.
- [ ] No P0, P1, or unaccepted P2 issue remains.

## 6. Accessibility verification

- [ ] Every interactive element has a concise, unique label; values, traits, state, and hints are correct.
- [ ] Visible text and meaningful images have accessible equivalents; decorative elements are hidden from VoiceOver.
- [ ] Focus order is logical and stable; screen changes move focus meaningfully.
- [ ] Modal content traps focus while open, supports dismissal, and restores focus to the initiating control.
- [ ] Every tap, swipe, drag, hold, multi-touch, rotor, and haptic-only action has a discoverable standard control or accessibility action.
- [ ] Screen Curtain does not change game behavior or stop audio.
- [ ] All 20 common tasks in [testflight-blind-test-plan.md](testflight-blind-test-plan.md) pass on required device/configuration rows.
- [ ] At least eight blind/low-vision external testers complete the release candidate; every tester independently completes onboarding and reaches an exit.
- [ ] Paired braille-display and Mono Audio passes are recorded.
- [ ] Xcode automated accessibility audits pass on every major screen, but are not used as a substitute for blind-user testing.
- [ ] Blind accessibility reviewer and product owner sign the report.
- [ ] Accessibility URL text matches the exact release.
- [ ] Accessibility Nutrition Label drafts claim only verified iPhone features. Prepare before launch; publish supported labels once version 1 is live.

Apple says VoiceOver support can be indicated only when all common tasks work using VoiceOver alone and without sighted assistance. [Apple VoiceOver evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria)

## 7. TestFlight

- [ ] Internal group `Echo Cave — Engineering` exists and the selected build passes Ring 0.
- [ ] External group `Echo Cave — Blind Accessibility RC` exists; email invitations are used for the focused cohort.
- [ ] Beta App Description, What to Test, feedback email, review contact, and notes are complete.
- [ ] External build has passed TestFlight App Review before invitations are sent.
- [ ] Testers receive accessible instructions and the TestFlight feedback privacy explanation.
- [ ] Feedback and crash items are triaged by severity and linked to the build/test matrix.
- [ ] A new release-candidate build reruns affected matrix rows; navigation/audio/storage changes trigger a full common-task regression.
- [ ] Final TestFlight report meets every exit criterion.

Apple supports up to 100 internal and 10,000 external testers, and builds can be tested for up to 90 days. [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)

## 8. Product-page metadata and media

- [ ] App name, subtitle, promotional text, description, and keywords are copied from [metadata-en-US.md](metadata-en-US.md) and pass field limits.
- [ ] Description contains no future, untested, or removed feature.
- [ ] “No data,” “offline,” “VoiceOver,” Screen Curtain, haptics, audio-only, Daily Cave, share, inventory, journal, and achievement claims match the build.
- [ ] Category and subcategory accurately describe the game.
- [x] Support URL is public HTTPS, contains `vidalsulieman@gmail.com`, and works without authentication.
- [x] Privacy URL is public HTTPS and works without authentication.
- [x] Accessibility URL is public HTTPS and works without authentication; keep its pre-release status until physical-device sign-off.
- [ ] Eight screenshots follow [media-plan.md](media-plan.md), show actual current app use, have no alpha, and contain no debug/private data.
- [ ] Accessible screenshot descriptions are retained and published on the marketing/accessibility site.
- [ ] Optional app preview is actual in-app footage, understandable muted, fully captioned, technically valid, and uses rights-cleared audio.
- [ ] Poster frame communicates gameplay rather than only title art.
- [ ] Metadata and media are proofread with VoiceOver and by a second human.

Apple accepts one to ten screenshots and up to three optional previews per device size/language. [Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)

## 9. Ratings, compliance, and review information

- [ ] Final content audit confirms the answers in [age-rating.md](age-rating.md).
- [ ] App Store Connect questionnaire is completed honestly; calculated global and regional ratings are saved as evidence.
- [ ] Expected 9+ result from infrequent horror/fear content is reconciled; investigate any unexpected result rather than forcing a lower rating.
- [ ] Made for Kids is No and age override is Not Applicable unless the product/legal decision changes.
- [ ] No unrestricted web access, UGC, chat, social feed, ads, contest, gambling, simulated gambling, or loot boxes exist.
- [ ] Review contact name, email, and phone are current and monitored.
- [ ] Copy-ready notes from [app-review-notes.md](app-review-notes.md) match exact labels and timing.
- [ ] Reviewer can complete the first cave and inspect every major feature without an account or network.
- [ ] Any non-obvious entitlement, content right, or accessibility behavior is explained and supporting attachment added if needed.

Apple requires an age rating and prevents Unrated apps from App Store publication. [Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating)

## 10. Submission and controlled release

- [ ] Correct processed build is selected; version/build/hash match the signed release record.
- [ ] Export-compliance status is complete and no build field is missing.
- [ ] All required metadata, screenshot wells, URLs, labels, ratings, and review contact fields are complete.
- [ ] Choose manual release for version 1.
- [ ] In App Store Connect, add the version to a review submission, inspect the draft, then submit for review. [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/)
- [ ] Monitor App Review messages and reproduce any issue on the immutable candidate before responding.
- [ ] If code/assets change, upload a new build and rerun all affected gates; do not silently invalidate signed evidence.
- [ ] After approval, run a final product-page, legal-rights, support, privacy, and availability check before manual release.
- [ ] Install from the live App Store on a clean iPhone and run launch, onboarding, VoiceOver, audio, offline, support/privacy link, purchase/price, and save smoke tests.
- [ ] Monitor only App Store/TestFlight-provided operational signals and direct support under the no-data model; do not enable Live Link after review.
- [ ] Preserve the release archive, signed checklist, rights ledger, privacy/network evidence, accessibility report, screenshots, review notes, and live store URL.

## Final authorization

| Role | Name | Date | Evidence/signature |
| --- | --- | --- | --- |
| Product owner |  |  |  |
| Engineering release owner |  |  |  |
| Blind accessibility reviewer |  |  |  |
| Privacy reviewer |  |  |  |
| Asset-rights reviewer |  |  |  |
| App Store Connect submitter |  |  |  |
