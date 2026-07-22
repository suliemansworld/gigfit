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

The installed profiles do not specifically cover `com.suliemansworld.echocave`, and no App Store Connect API key was present. Before archive upload, confirm the team in the owner's Apple account, register the final App ID, create or let Xcode manage the required Echo Cave profiles, and validate a signed archive with Xcode 26 or later.

## ElevenLabs narration attestation

Sulieman Vidal states that:

- He personally created the Echo Cave narration clips using ElevenLabs.
- He had a paid ElevenLabs subscription at the time.
- The plan represented generated output as available for commercial use.
- He owns or controls the Echo Cave scripts supplied to the service.

This statement corrects the repository handoff's unsupported characterization of 79 MP3 files as free-tier output. It is an owner attestation, not a substitute for a rights review of the exact subscription and terms.

## Billing evidence received

On July 22, 2026, the owner supplied a screenshot of an ElevenLabs Inc. Stripe credit note. The image identifies a **Creator** subscription priced at **US$22 per month** and a credit-note issue date of **June 16, 2026**. This corroborates the paid-plan attestation and resolves the exact plan/price uncertainty.

The screenshot contains an account email and billing identifiers, so it is intentionally excluded from Git. Its SHA-256 is:

`7adfb7e31a3a1208df217a70b0cc09fbe7eea74d8d48778791642be383964ca4`

The credit note alone does not establish the subscription coverage dates for every clip. Preserve the original image and retrieve the associated invoice or account billing history showing that the Creator plan covered the relevant generation dates.

## Evidence still to preserve outside Git

Before App Store submission, retain these items in an access-controlled, owner-controlled folder and add a stable reference to [asset-rights-ledger.md](asset-rights-ledger.md):

- The associated ElevenLabs invoice, receipt, card statement, or billing export covering the generation period.
- Account subscription/history export confirming the Creator plan coverage dates.
- Generation-history export or other record connecting the account and dates to the shipping clips.
- The ElevenLabs terms and any voice/model terms that applied on those dates.
- A short rights-review sign-off confirming commercial iOS distribution and marketing use.

Do not commit receipts, account exports, payment details, credentials, API keys, or identity documents to this repository.
