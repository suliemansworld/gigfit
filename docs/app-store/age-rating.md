# Age-rating guidance

Status: Draft questionnaire answers for the final Echo Cave 1.0 content review.

Apple now derives global and region-specific ratings from the App Store Connect questionnaire. The current global values for devices on iOS 26 or later are 4+, 9+, 13+, 16+, 18+, and Unrated. [Apple age-rating values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)

## Expected outcome

Expected global rating: **9+**, based on **Infrequent Horror or Fear Themes**.

Echo Cave takes place in darkness with tense cave ambience and narrative references to a small bird bone and a bone whistle. There is no combat, injury, gore, threat, or graphic imagery. Selecting the infrequent fear descriptor is a conservative and transparent fit. Apple calculates the final result and may produce different regional ratings.

## Draft questionnaire answers

### In-app controls and capabilities

| Item | Answer | Rationale |
| --- | --- | --- |
| Parental Controls | No | No child-management or content restriction system. |
| Age Assurance | No | No age collection or verification. |
| Unrestricted Web Access | No | No browser or free navigation to websites. Support/privacy links, if present, are fixed destinations. |
| User-Generated Content | No | Players do not publish content through Echo Cave. |
| Social Media | No | No feed, reactions, profiles, discovery, or redistribution system. |
| Social Media Disabled for Users Under 13 | No | No social media feature exists. |
| Messaging and Chat | No | No player-to-player communication. |
| Advertising | No | No ads or ad SDK. |

The user-initiated iOS share sheet for a plain-text Daily Cave result is not an in-app social feed, messaging service, or unrestricted browser. Reassess if sharing behavior changes.

### Mature themes

| Content descriptor | Answer | Rationale |
| --- | --- | --- |
| Profanity or Crude Humor | None | No profanity or crude humor identified. |
| Horror or Fear Themes | **Infrequent** | Darkness, cave tension, eerie ambience, a small bird bone, and a bone whistle. |
| Alcohol, Tobacco, or Drug Use or References | None | Not present. |

### Medical or wellness

| Content descriptor | Answer | Rationale |
| --- | --- | --- |
| Medical or Treatment Information | None | Not present. |
| Health or Wellness Topics | None | The app is entertainment, not health guidance. |

### Sexuality or nudity

| Content descriptor | Answer |
| --- | --- |
| Mature or Suggestive Themes | None |
| Sexual Content or Nudity | None |
| Graphic Sexual Content or Nudity | None |

### Violence and weapons

| Content descriptor | Answer | Rationale |
| --- | --- | --- |
| Cartoon or Fantasy Violence | None | No combat or harm. |
| Realistic Violence | None | No combat, injury, or harm. |
| Prolonged Graphic or Sadistic Realistic Violence | None | Not present. |
| Guns or Other Weapons | None | A rope, compass fragment, echo stone, bird bone, and bone whistle are not used as weapons. |

### Chance-based activities

| Content descriptor | Answer | Rationale |
| --- | --- | --- |
| Contests | None | Daily Cave is a solo same-seed challenge with no rankings, opponent, prize, or competitive reward. |
| Gambling | No/None | No wagering or real-world value. |
| Simulated Gambling | None | No simulated betting or wagering. |
| Loot Boxes | No | Random exploration finds are neither purchased nor sold and are not paid virtual containers. |

### Additional information

| Field | Answer |
| --- | --- |
| Made for Kids | No |
| Age category override | Not Applicable |
| Age Suitability URL | Optional; use the public version of this page only if maintained |

Apple instructs developers to answer each descriptor's frequency honestly, then select Not Applicable when no Kids category or higher override is needed. [Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating)

## Final-content audit

- [ ] Search final narration text, journal text, achievements, item descriptions, alerts, screenshots, and preview audio for every questionnaire descriptor.
- [ ] Play every procedural content pool and Daily Cave path available in 1.0.
- [ ] Confirm random items cannot be bought and have no cash-equivalent value.
- [ ] Confirm there are no rankings, Game Center leaderboards, or contests.
- [ ] Confirm fixed support/privacy links do not open an unrestricted in-app browser.
- [ ] Save screenshots of the completed questionnaire and calculated global/regional results.
- [ ] Reconcile the displayed rating with product-page copy and parental-control behavior.
- [ ] Repeat this audit whenever content, communication, sharing, monetization, or web access changes.
