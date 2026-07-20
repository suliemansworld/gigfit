# GigFit Agent Handoff

This is the operational handoff for another coding agent working on GigFit.

## Current status

- Repository: `https://github.com/suliemansworld/gigfit`
- Branch: `main`
- Bundle ID: `com.suliemansworld.GigFit`
- App Store Connect app ID: `6792892535`
- Apple team: `Sulieman Haidari`
- App Store Connect issuer ID: `fa21a325-1c75-4361-a1df-012223cbb5ef`
- Codemagic app ID: `6a5e8d6ad0ba9e4019350389`
- TestFlight group: `GigFit Internal` with automatic distribution enabled
- Internal tester: `haidari.sulieman@gmail.com`
- Latest verified upload: Build 6, reported `VALID` by Apple on July 20, 2026
- Build 6: `https://codemagic.io/app/6a5e8d6ad0ba9e4019350389/build/6a5ea0c02553a950a2c1f517`
- Build 6 source includes commit `e5e74db` and tag `testflight-volume-20260720-1`

If Build 6 does not appear immediately in TestFlight, inspect `GigFit Internal` and add it manually.

## Product behavior

GigFit is a SwiftUI/ARKit cargo-volume app targeting iPhone and iOS 17+.

The scan is a four-stage workflow:

1. Calibrate the floor by targeting it or placing the phone over a floor corner.
2. Target the opposite floor edge to set width.
3. Target the far floor edge to set depth and create a rectangular base.
4. Raise the phone; the wireframe expands live. Lock height at the phone or target an upper surface.

The coordinator generates the eight corners required by the existing geometry, persistence, calibration, and review code. Do not reintroduce independent eight-dot placement.

LiDAR devices enable mesh reconstruction and smoothed scene depth. Other supported iPhones use ARKit planes. Never restore the old fake fallback that placed a point two meters in front of the camera.

## Important files

- `GigFit/AR/ARScanCoordinator.swift`: scan state machine and live volume
- `GigFit/AR/PointPlacementService.swift`: raycasting and LiDAR depth unprojection
- `GigFit/AR/ARSessionController.swift`: LiDAR and mesh configuration
- `GigFit/AR/ARScanView.swift`: ARSCNView wrapper and crosshair
- `GigFit/AR/MarkerEntityFactory.swift`: markers and wireframe geometry
- `GigFit/Views/ScanView.swift`: live scanning interface
- `GigFit/Views/ScanInstructionsView.swift`: workflow instructions
- `GigFit/Geometry/VolumeCalculator.swift`: six-tetrahedron volume
- `GigFit/Views/CalibrationView.swift`: optional tape calibration
- `codemagic.yaml`: CI and TestFlight workflows

## Local development

The MacBook has Xcode 15.2. It can compile this iOS 17 project, while Codemagic supplies current Xcode, signing, and TestFlight uploads.

Build without signing:

```sh
xcodebuild -quiet \
  -project GigFit.xcodeproj \
  -scheme GigFit \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/gigfit-device \
  CODE_SIGNING_ALLOWED=NO build
```

Run tests using an ID from `xcrun simctl list devices available`:

```sh
xcodebuild -quiet \
  -project GigFit.xcodeproj \
  -scheme GigFitTests \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' \
  -derivedDataPath /tmp/gigfit-tests \
  CODE_SIGNING_ALLOWED=NO test
```

At handoff, the device build and full suite pass. ARKit and LiDAR still require physical-iPhone testing.

## Codemagic

Use workflow `gigfit-testflight`. Encrypted group `app_store_credentials` contains:

- `APP_STORE_CONNECT_PRIVATE_KEY`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `CERTIFICATE_PRIVATE_KEY`

Never commit or print their values. The App Store Connect key is locally stored at `/Users/suliemanvidal/Downloads/AuthKey_CB7RGT35JW.p8`. Active key ID: `CB7RGT35JW`.

An older unusable key named `GigFit Codemagic`, ID `75YD58U4CV`, has a lost one-time download. Revoke it only with the owner's explicit approval.

The workflow sets `CFBundleVersion` from `BUILD_NUMBER`, fetches signing files, builds an IPA, and publishes it. Tags matching `testflight-*` are configured as release triggers, but the Codemagic webhook may need refreshing. Manual triggering is reliable.

## Release procedure

1. Check `git status` and review the intended diff.
2. Run the device build and tests above.
3. Commit and push `main`.
4. In Codemagic, click **Start new build**.
5. Select branch `main` and workflow `GigFit TestFlight`.
6. Start without SSH/VNC unless debugging needs it.
7. Wait through IPA build, Publishing, and App Store distribution.
8. Verify the build in App Store Connect/TestFlight.
9. Confirm it is in `GigFit Internal` and the tester is invited.
10. Open TestFlight on the iPhone with `haidari.sulieman@gmail.com` and update GigFit.

Another app may occupy the only concurrent Codemagic builder. Leave GigFit queued instead of canceling unrelated work.

## Apple/TestFlight notes

- GigFit uses no non-exempt encryption. Answer **No** when asked about encryption.
- Internal testing does not require external beta-review contact information.
- Codemagic may report missing Feedback Email and review-contact details after a successful upload. That affects external beta review, not internal testing.
- Build 5 compliance was completed and it became Ready to Test.

## Known risks

- Validate floor offset and LiDAR depth on the user's exact iPhone.
- Phone-on-floor calibration subtracts 2.5 cm from camera height. Tune against a tape measure.
- Move slowly in a well-lit space while tracking initializes.
- The current model measures a rectangular volume. Irregular spaces need editable handles or another mode.
- `VolumeCalculator` was fixed from an invalid five-tetrahedron decomposition to six. Do not revert it; regression tests cover boxes, sloped tops, and insets.

## Security

- Never request Apple passwords, two-factor codes, private keys, or certificates in chat.
- Let the user authenticate directly in Apple's UI.
- Never commit `.p8`, `.p12`, profiles, certificates, or API tokens.
- Do not revoke keys or certificates without explicit approval.

