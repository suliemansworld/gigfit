# Echo Cave App Store package

Last verified against Apple documentation: July 22, 2026

This directory is the working source of truth for the Echo Cave 1.0 App Store submission. Version 1 is scoped to iPhone only, with English (U.S.) as the primary localization and iOS 15.0 as the minimum deployment target.

## Submission status

The store copy and operational plans are ready to use, but the app is **not ready to submit** until every release blocker below is closed:

- [x] The owner's paid ElevenLabs subscription and commercial-use recollection are recorded in [owner-confirmations.md](owner-confirmations.md).
- [x] A June 16, 2026 Stripe credit note corroborates an ElevenLabs Creator subscription at US$22/month; its non-sensitive facts and image hash are recorded without committing billing data.
- [ ] The associated invoice/account coverage history, generation history, and applicable terms have been preserved and reviewed for the shipping narration. See [asset-rights-ledger.md](asset-rights-ledger.md).
- [ ] Every other narration, ambience, effect, music, icon, font, and marketing asset has a complete rights record and an `APPROVED` status.
- [x] Diagnostics “Live Link” and its `/diag/` request path were removed from the source on July 22, 2026.
- [ ] A release-archive network audit confirms that ordinary play, diagnostics, launch, relaunch, and failure paths transmit no app data.
- [ ] Blind testers can complete every common task with VoiceOver and Screen Curtain without sighted help. See [testflight-blind-test-plan.md](testflight-blind-test-plan.md).
- [ ] App metadata claims have been reconciled against the exact submitted build, including screenshots, privacy answers, age rating, and accessibility labels.
- [x] Privacy, support, and pre-release accessibility pages are public over HTTPS, and the app includes direct privacy/support links and contact email. Add the accessibility URL to App Store Connect only after blind-player sign-off.
- [ ] The final archive is built with Xcode 26 or later and an iOS 26 SDK or later. Apple has required that toolchain for uploads since April 28, 2026.

Apple requires final builds, complete metadata, working URLs, and on-device testing under App Review Guideline 2.1. Metadata must accurately reflect the submitted build under Guideline 2.3. [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Package contents

| File | Purpose |
| --- | --- |
| [metadata-en-US.md](metadata-en-US.md) | Copy-ready English (U.S.) product-page metadata |
| [app-review-notes.md](app-review-notes.md) | Reviewer instructions and a deterministic review path |
| [privacy-and-labels.md](privacy-and-labels.md) | App Privacy and Accessibility Nutrition Label drafts |
| [accessibility.md](accessibility.md) | Public accessibility statement and verification gates |
| [age-rating.md](age-rating.md) | Draft age-rating questionnaire answers and rationale |
| [media-plan.md](media-plan.md) | Screenshot order, accessible descriptions, and preview storyboard |
| [testflight-blind-test-plan.md](testflight-blind-test-plan.md) | Blind-tester recruitment, device matrix, tasks, and exit gates |
| [asset-rights-ledger.md](asset-rights-ledger.md) | Rights evidence template and ElevenLabs documentation gate |
| [owner-confirmations.md](owner-confirmations.md) | Confirmed app identity and paid-plan narration attestation |
| [release-checklist.md](release-checklist.md) | End-to-end TestFlight and App Store submission checklist |
| [`../../PRIVACY.md`](../../PRIVACY.md) | Public privacy policy source |
| [`../../SUPPORT.md`](../../SUPPORT.md) | Public support-page source |

## Product assumptions

- No account, login, backend, advertising, analytics, tracking, in-app purchase, or subscription in version 1.
- Game data and settings stay on the device.
- All required game audio ships in the app and play works without a network connection.
- Sharing a daily result is a user-initiated iOS share-sheet action; Echo Cave does not receive the destination or message after it leaves the app.
- On-device diagnostics may display local state but may not transmit it in the App Store build.
- iPad is post-launch scope. Do not create iPad submission metadata or claims for version 1. Future iPad work must include a separate accessibility and no-haptics test pass.

If any assumption changes, update the privacy policy, labels, review notes, screenshots, and checklist before uploading the next build.

## Current Apple references

- [App information field definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [Platform version field definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Accessibility Nutrition Labels overview](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/)
- [Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [Current SDK upload requirements](https://developer.apple.com/news/upcoming-requirements/)
- [Xcode system requirements](https://developer.apple.com/xcode/system-requirements/)
