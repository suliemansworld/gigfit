# Owner confirmations

Recorded July 22, 2026 for the Echo Cave 1.0 release record.

## App identity

- Product name: `Echo Cave`
- Bundle identifier: `com.suliemansworld.echocave`
- Public support email: `vidalsulieman@gmail.com`
- Version 1 platform scope: iPhone, English (U.S.), minimum iOS 15.0

Sulieman Vidal confirmed these values for the App Store project. The bundle identifier must be re-confirmed in App Store Connect before the first build upload because it cannot be changed for that app record afterward.

## Apple signing discovery

The local keychain contains valid Apple development and distribution identities, and all three installed Xcode-managed provisioning profiles identify Apple Team `36R3VCWWUJ`. The Xcode app and UI-test targets preselect that team for automatic signing.

Codemagic subsequently resolved or created the App Store distribution profile for `com.suliemansworld.echocave`, signed version 1.0 build 2 with Xcode 26.6, and uploaded it successfully. Apple processed the build to **Internal — Ready to Test**. See [testflight-build-evidence.md](testflight-build-evidence.md).

## ElevenLabs narration attestation

Sulieman Vidal states that:

- He personally created the Echo Cave narration clips using ElevenLabs.
- He had a paid ElevenLabs subscription at the time.
- The plan represented generated output as available for commercial use.
- He owns or controls the Echo Cave scripts supplied to the service.

This statement corrects the repository handoff's unsupported characterization of 79 MP3 files as free-tier output. It is an owner attestation, not a substitute for a rights review of the exact subscription and terms.

## Original WAV rights and release instruction

After testing TestFlight build 2 on July 22, 2026, Sulieman Vidal directly confirmed that he holds the commercial rights to **all 636 WAV files** in the Echo Cave repository and instructed that those original recordings be restored to the iOS game. This includes 613 narration WAVs under `audio/voice/` and 23 ambience, bed, effect, footstep, friction, and loop WAVs directly under `audio/`.

Build 2 did not preserve those files: its release pipeline converted 610 narration WAVs to M4A and selected MP3 alternatives for the gameplay recordings. The corrected release pipeline must bundle every WAV byte-for-byte and fail verification if any WAV is omitted, renamed, transcoded, or changed. This paragraph records the owner's rights attestation and shipping instruction; the documentary evidence checklist below remains the formal App Store clearance record.

## Billing evidence received

On July 22, 2026, the owner supplied a screenshot of an ElevenLabs Inc. Stripe credit note. The image identifies a **Creator** subscription priced at **US$22 per month** and a credit-note issue date of **June 16, 2026**. This corroborates the paid-plan attestation and resolves the exact plan/price uncertainty.

The screenshot contains an account email and billing identifiers, so it is intentionally excluded from Git. Its SHA-256 is:

`7adfb7e31a3a1208df217a70b0cc09fbe7eea74d8d48778791642be383964ca4`

The credit note alone does not establish the subscription coverage dates for every clip. Preserve the original image and retrieve the associated invoice or account billing history showing that the Creator plan covered the relevant generation dates.

## API request-log evidence received

On July 22, 2026, the owner also supplied an ElevenLabs API request-log CSV containing 19 successful requests between **02:31:22 and 02:33:17 (UTC-7)**. The export includes one successful `GET /v1/user/subscription`, four successful usage-analytics requests, and voice/model metadata requests.

The CSV records request metadata only. It contains no response bodies, subscription-plan value, invoice period, generation endpoint, clip identifier, or historical clip-generation date. It corroborates access to an ElevenLabs account and its subscription/analytics interfaces on July 22, 2026, but it does **not** establish that the Creator plan covered the shipping clips when they were generated.

The CSV contains user, event, and trace identifiers, so it is intentionally excluded from Git. Its SHA-256 is:

`19a1e0e01e6cc223581672be1ab5120ad42c188b735ec868d535d999054650ef`

## Evidence still to preserve outside Git

Before App Store submission, retain these items in an access-controlled, owner-controlled folder and add a stable reference to [asset-rights-ledger.md](asset-rights-ledger.md):

- The associated ElevenLabs invoice, receipt, card statement, or billing export covering the generation period.
- Account subscription/history export confirming the Creator plan coverage dates.
- Generation-history export or other record connecting the account and dates to the shipping clips.
- The ElevenLabs terms and any voice/model terms that applied on those dates.
- A short rights-review sign-off confirming commercial iOS distribution and marketing use.

Do not commit receipts, account exports, payment details, credentials, API keys, or identity documents to this repository.
