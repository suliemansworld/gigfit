# Echo Cave 1.0 TestFlight build evidence

Recorded July 22, 2026 for the first processed Echo Cave internal TestFlight build.

## App Store Connect record

- App name: `Echo Cave`
- Apple app ID: `6793576756`
- Bundle identifier: `com.suliemansworld.echocave`
- SKU: `echo-cave-ios-1`
- Platform: iOS, iPhone only
- Primary language: English (U.S.)

## Signed build

- Marketing version: `1.0`
- Build number: `2`
- Source commit: `6774174c6e2d0836287c6434ce59abc23c06c949`
- Builder: Codemagic macOS `mac_mini_m2`
- Xcode: `26.6`
- Minimum iOS version: `15.0`
- Distribution: App Store, TestFlight Internal Testing Only
- Codemagic evidence: [Echo Cave TestFlight build 2](https://codemagic.io/app/6a5e8d6ad0ba9e4019350389/build/6a60dae941214f7ff891e2a4)

The workflow passed its locked dependency install, offline Capacitor bundle synchronization, static release checks, signing-file/profile resolution, certificate installation, internal-only export configuration, signed IPA archive, and IPA content verification. Codemagic retained the IPA and dSYM artifacts with the build.

The App Store Connect upload completed with no errors. Apple processed the build and reported it as **Build 2 — Internal — Ready to Test**, with a 90-day TestFlight expiration window.

## Source verification

The exact source commit passed both repository checks:

- Browser tests: [GitHub Actions job](https://github.com/suliemansworld/echo-cave/actions/runs/29929244497/job/88954272498)
- iOS UI and accessibility tests: [GitHub Actions job](https://github.com/suliemansworld/echo-cave/actions/runs/29929244497/job/88954272656)

## Scope of this evidence

This evidence proves successful automated checks, signing, upload, and Apple processing. It does not replace physical-device VoiceOver testing, blind-player TestFlight sign-off, the release privacy/network audit, asset-rights clearance, metadata completion, export-compliance answers, or App Review.
