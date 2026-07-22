# Asset-rights ledger

Status: **PENDING documentary verification for commercial App Store release.** This is a clearance workflow, not legal advice.

Apple requires apps containing third-party content to have all necessary rights for every App Store country or region where the app is offered. [Apple app information — Content Rights](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)

## Release rule

An asset may ship only when its row is complete, the evidence is stored in a durable owner-controlled location, the allowed uses include commercial mobile-app distribution and App Store marketing in all intended territories, and status is `APPROVED` by the rights reviewer.

Allowed status values:

- `BLOCKED` — known rights conflict or commercial permission missing.
- `PENDING` — provenance or evidence incomplete.
- `APPROVED` — evidence reviewed and commercial uses cleared.
- `REPLACED` — prohibited asset is absent from the archive and replaced by an approved file.
- `REMOVED` — prohibited asset is absent with no replacement.

## ElevenLabs paid-plan attestation and evidence gap

The April 28, 2026 handoff labels exactly 79 MP3 narration atoms as free-tier output. On July 22, 2026, Sulieman Vidal directly corrected that characterization and attested that he personally generated the Echo Cave clips under a paid ElevenLabs subscription represented as commercially usable. He then supplied a June 16, 2026 Stripe credit-note screenshot identifying the subscription as **Creator at US$22 per month**. See [owner-confirmations.md](owner-confirmations.md).

The attestation plus credit note establishes meaningful paid-plan provenance and removes the known-free-tier conflict. A July 22, 2026 API request-log export additionally corroborates access to the account's subscription and usage-analytics interfaces, but contains no response payloads, plan value, clip identifiers, or historical generation dates; its SHA-256 and review are recorded in [owner-confirmations.md](owner-confirmations.md). The remaining gap is temporal: the associated invoice/account history, exact generation dates, and then-current terms have not yet been preserved in the release record. ElevenLabs states that paid-plan output generally receives a commercial license subject to its terms. Preserve evidence that the Creator plan covered the generation period plus the applicable terms before changing the batch to `APPROVED`. If that evidence cannot be recovered, regenerate the affected lines under a verified commercial plan. [ElevenLabs publishing guidance](https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform) and [current ElevenLabs Terms of Service](https://elevenlabs.io/terms-of-use)

### Batch record

| Field | Current value |
| --- | --- |
| Asset batch | `audio/voice/*.mp3` listed below |
| Count | **79** |
| Script/input owner | Sulieman Vidal — owner confirmation received; preserve source-text evidence |
| Generator | ElevenLabs |
| Generation tier | ElevenLabs Creator, US$22/month — owner-attested and corroborated by a June 16, 2026 Stripe credit-note screenshot; generation-period coverage pending |
| Intended use | Bundled commercial iPhone game, TestFlight, App Store, product-page preview/marketing |
| Current commercial evidence | Owner attestation plus owner-retained credit-note screenshot and API request-log export, SHA-256 fingerprints recorded in [owner-confirmations.md](owner-confirmations.md); the request log has no response payloads or historical generation dates, and associated invoice, coverage history, generation-history export, and dated terms remain outstanding |
| Current status | **PENDING — Creator plan corroborated; generation-period coverage and terms review outstanding** |
| Required resolution | Archive and review evidence that the Creator plan covered the generation period plus the applicable commercial terms; regenerate only if adequate historical evidence cannot be recovered |
| Final reviewer/date |  |

### Exact 79-file verification checklist

Every file below is currently **`PENDING — covered by the paid-plan owner attestation; documentary verification outstanding`**:

1. `audio/voice/ach-1-earned.mp3`
2. `audio/voice/ach-10-earned.mp3`
3. `audio/voice/ach-2-earned.mp3`
4. `audio/voice/ach-3-earned.mp3`
5. `audio/voice/ach-4-earned.mp3`
6. `audio/voice/ach-5-earned.mp3`
7. `audio/voice/ach-6-earned.mp3`
8. `audio/voice/ach-7-earned.mp3`
9. `audio/voice/ach-8-earned.mp3`
10. `audio/voice/ach-9-earned.mp3`
11. `audio/voice/ach-none-yet.mp3`
12. `audio/voice/base-stage1-prefix.mp3`
13. `audio/voice/base-stage2-prefix.mp3`
14. `audio/voice/base-tail-stage1-1.mp3`
15. `audio/voice/base-tail-stage1-2.mp3`
16. `audio/voice/base-tail-stage1-3.mp3`
17. `audio/voice/base-tail-stage1-4.mp3`
18. `audio/voice/base-tail-stage2-1.mp3`
19. `audio/voice/base-tail-stage2-2.mp3`
20. `audio/voice/base-tail-stage2-3.mp3`
21. `audio/voice/base-tail-stage2-4.mp3`
22. `audio/voice/base-tail-stage2-5.mp3`
23. `audio/voice/base-tail-stage2-6.mp3`
24. `audio/voice/braille-close.mp3`
25. `audio/voice/braille-copy.mp3`
26. `audio/voice/closed-generic.mp3`
27. `audio/voice/help-and-tips.mp3`
28. `audio/voice/help-intro.mp3`
29. `audio/voice/help-short.mp3`
30. `audio/voice/help-shortcuts-summary.mp3`
31. `audio/voice/help-slash-hint.mp3`
32. `audio/voice/inv-drop-echo-stone-1.mp3`
33. `audio/voice/inv-drop-echo-stone-2.mp3`
34. `audio/voice/inv-drop-echo-stone-3.mp3`
35. `audio/voice/inv-pickup-echo-stone.mp3`
36. `audio/voice/inv-use-compass-1.mp3`
37. `audio/voice/inv-use-compass-2.mp3`
38. `audio/voice/inv-use-compass-3.mp3`
39. `audio/voice/listen-off.mp3`
40. `audio/voice/listen-on.mp3`
41. `audio/voice/menu-open.mp3`
42. `audio/voice/rotor-achievements.mp3`
43. `audio/voice/rotor-back-personal.mp3`
44. `audio/voice/rotor-cave-map.mp3`
45. `audio/voice/rotor-close-achievements.mp3`
46. `audio/voice/rotor-close-help.mp3`
47. `audio/voice/rotor-close-journal.mp3`
48. `audio/voice/rotor-daily-cave.mp3`
49. `audio/voice/rotor-descend-deeper.mp3`
50. `audio/voice/rotor-help-and-tips.mp3`
51. `audio/voice/rotor-inventory.mp3`
52. `audio/voice/rotor-journal.mp3`
53. `audio/voice/rotor-print-braille.mp3`
54. `audio/voice/rotor-read-achievements.mp3`
55. `audio/voice/rotor-read-journal.mp3`
56. `audio/voice/rotor-replay-tutorial.mp3`
57. `audio/voice/rotor-reset-cave.mp3`
58. `audio/voice/rotor-settings.mp3`
59. `audio/voice/rotor-teleport-home.mp3`
60. `audio/voice/settings-audio-rumble.mp3`
61. `audio/voice/settings-boost-volume.mp3`
62. `audio/voice/settings-close.mp3`
63. `audio/voice/settings-crossover.mp3`
64. `audio/voice/settings-door-hints.mp3`
65. `audio/voice/settings-door-pings.mp3`
66. `audio/voice/settings-gesture-sounds.mp3`
67. `audio/voice/settings-haptic.mp3`
68. `audio/voice/settings-hide-pad.mp3`
69. `audio/voice/settings-listen-auto.mp3`
70. `audio/voice/settings-mainvein-chime.mp3`
71. `audio/voice/settings-pure-audio.mp3`
72. `audio/voice/settings-saved.mp3`
73. `audio/voice/settings-spoken-narration.mp3`
74. `audio/voice/settings-swipe-gestures.mp3`
75. `audio/voice/settings-test-as-new.mp3`
76. `audio/voice/toggle-off.mp3`
77. `audio/voice/toggle-on.mp3`
78. `audio/voice/tutorial-part-2.mp3`
79. `audio/voice/tutorial-tap-begin.mp3`

After historical evidence is reviewed, change the batch to `APPROVED` and record its durable evidence location and reviewer. If regeneration is required instead, preserve an old-to-new mapping, confirm all 79 old hashes are absent from the archive, update `audio/voice/manifest.json`, and change each status to `REPLACED` only after the replacement row is `APPROVED`.

## Other current asset groups

These groups also need evidence; do not infer rights from their presence in the repository.

| Asset group | Count/scope | Known source | Evidence needed | Status |
| --- | --- | --- | --- | --- |
| Narration WAV files | 610 referenced files plus 3 unreferenced legacy files in `audio/voice/` | Sulieman Vidal attests that he generated the Echo Cave clips under the same paid ElevenLabs subscription; exact account, plan, voice terms, and dates are not recorded here | Generation history/dates, account and subscription evidence, model/voice usage terms, commercial grant, input ownership, file hashes | `PENDING` |
| Root ambience, beds, effects, footsteps, friction, loops, welcome music | All `.wav`/`.mp3` files directly under `audio/` | Not fully documented | Original recordings/project files or supplier URLs/receipts/licenses; allowed app and marketing uses; attribution; modifications; territory/term | `PENDING` |
| App/PWA icons | `icons/` and final iOS AppIcon set | Not fully documented | Designer/source, editable original, font/stock inputs, commercial assignment/license, generated-art terms if applicable | `PENDING` |
| App copy and story text | `index.html`, manifest narration text, native resources | Sulieman Vidal/project | Author confirmation and any collaborator assignment | `PENDING` |
| Fonts | Final archive and screenshots | System font intended | Confirm only Apple system fonts or record embedded font license | `PENDING` |
| Screenshots and preview | Final App Store media | To be captured from approved build | Creator, capture date/build, all visible/audio asset clearance, releases if any personal data appears | `PENDING` |
| Third-party code/SDK notices | Final archive | None intended | Dependency inventory, licenses, notice obligations, privacy manifests | `PENDING` |

## Per-asset ledger template

Copy one row per asset or homogeneous licensed batch. Do not combine assets with different creation dates, plans, suppliers, voices, or license terms.

| Field | Required entry |
| --- | --- |
| Ledger ID | Stable unique identifier |
| Repository path(s) | Exact path or enumerated manifest |
| SHA-256 | Hash of the approved shipping file(s) |
| Asset type | Narration, SFX, music, ambience, icon, font, copy, screenshot, video, code |
| Title/description | Human-readable identification |
| Creator/performer | Legal name and role |
| Source/tool/vendor | Original recording, ElevenLabs, stock provider, contractor, etc. |
| Creation/generation date | Exact date/time where available |
| Account owner | Owner of the vendor/tool account |
| Plan/tier at creation | Exact commercial tier; attach invoice/subscription evidence |
| Voice/model/product | Exact voice, model, sound-effects product, or source pack |
| Input/script owner | Owner and evidence for text, recordings, or prompts |
| License/assignment | Exact agreement/version and relevant clauses |
| Permitted uses | Commercial iOS app, TestFlight, App Store product page, website, social marketing, trailers |
| Territory and term | Worldwide/perpetual or actual limitations |
| Attribution | Required text and placement, or None |
| Restrictions | Standalone distribution, sublicensing, audience, revenue, edits, model-specific limits |
| Evidence location | Owner-controlled PDF/export/receipt/contract path; not an expiring browser tab |
| Replacement for | Old asset path/hash if regenerated |
| Reviewer | Person who inspected evidence |
| Review date | ISO date |
| Status | `BLOCKED`, `PENDING`, `APPROVED`, `REPLACED`, or `REMOVED` |
| Notes | Open questions and follow-up |

## ElevenLabs clearance evidence packet

For historical clearance, retain:

- Paid-plan invoice and account/subscription page export covering the exact generation date.
- The ElevenLabs Terms of Service and applicable service/model/voice terms in force on that date.
- Generation history/export showing file, text, voice/model, timestamp, and account.
- Proof that the script/input is owned or licensed by Echo Cave.
- Proof the selected voice/model is permitted for the planned commercial mobile-app and marketing uses.
- Original downloaded output hash and normalized shipping-file hash.
- Written reviewer sign-off.

If historical evidence cannot be recovered and regeneration is used, also retain:

- A mapping from each superseded file to its approved replacement.
- A manifest validation showing all referenced files exist and all superseded hashes are absent.

Do not commit API keys, invoices containing payment details, identity documents, or private vendor exports to the repository. Store sensitive evidence in an access-controlled owner location and place only a stable reference in this ledger.

## Final rights sign-off

| Check | Reviewer/date |
| --- | --- |
| Paid-plan owner attestation recorded | Sulieman Vidal / July 22, 2026 |
| All 79 MP3s supported by reviewed historical evidence or replaced |  |
| All 610 referenced narration WAVs approved |  |
| All ambience, SFX, loops, footsteps, beds, and music approved |  |
| Icons, fonts, copy, screenshots, and preview approved |  |
| Third-party code licenses/notices complete |  |
| No `BLOCKED` or `PENDING` asset appears in archive |  |
| App Store Content Rights answer reconciled |  |
