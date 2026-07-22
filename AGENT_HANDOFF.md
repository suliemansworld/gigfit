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
- Latest verified build: #21 (commit `c3df9fb`, tag `testflight-roadieload-20260721-1`)
- Build 21: `https://codemagic.io/app/6a5e8d6ad0ba9e4019350389/build/6a6027ef35765eb29d51b8f5`

## Product behavior

GigFit is a SwiftUI/ARKit cargo-volume app targeting iPhone and iOS 17+. It now supports four scan modes.

### Manual Rectangle Mode (default)

This is the primary workflow — measure any object by placing corners:

1. The crosshair continuously detects surfaces and shows a white ring + cross at the hit point. "Surface found! Tap to place point" appears in the status bar when a surface is detected.
2. Tap to place the floor corner. A live measurement line (with distance label) follows from the corner to the crosshair as you move.
3. Tap to set width. A **transparent blue rectangle** fills between the width line and the crosshair, updating live as you pan.
4. Tap to set depth. The 3D wireframe base locks in.
5. Raise the phone; the wireframe expands live. Lock height at the phone or target an upper surface.
6. Tap **Quick Review** to skip calibration and see the 3D model + measurements. The tape calibrate button is still available as a secondary option.

The coordinator generates 8 corners from floor origin + width + depth vectors. Do not reintroduce independent eight-dot placement.

### Polygon Mode

Tap "Polygon Scan" from the home screen. Place multiple vertices on the floor to trace any shape:
- Each vertex snaps to detected planes (ARPlaneAnchor, horizontal) for stability, falling back to mesh vertices only if no plane is within 25cm.
- The polygon outline renders live. Area is shown in sq ft.
- Tap the checkmark to close the shape. Then raise for height like rectangle mode.
- Volume = polygon area (shoelace formula) × height.

### Auto Room Mode

Switch from manual mode via the hand icon button. The phone pans around the room and a bounding box expands from detected planes and LiDAR mesh. Lock when ready. Uses scene reconstruction (heavier — keep it for LiDAR devices only).

### 3D Room Scan (RoomPlan)

"3D Room Scan" button on home screen. Uses Apple's RoomPlan framework for true 3D room capture with wall/door/window/furniture detection. Exports USDZ. Requires LiDAR iPhone (Pro 12+).

### Roadie Live Load Tracker (v1)

The first usable slice of the original delivery-driver MVP is implemented:

1. Start a load from a saved cargo-space scan or vehicle profile.
2. Add a package using manual dimensions or a previously measured GigFit scan.
3. Optionally attach a Roadie or other gig-app screenshot through the system photo picker, add notes, and set quantity.
4. Track each package as loaded or delivered. Quantity changes, deliveries, deletions, and app relaunches update the remaining-space tally immediately.
5. The dashboard shows occupied volume, remaining volume, total conservative vehicle capacity, and a large remaining-space percentage (for example, 36% occupied displays 64% space left).

Capacity v1 is an honest volume utilization estimate: `loaded package volume × quantity` is subtracted from the vehicle's conservative measured capacity. It does not yet prove that differently shaped packages can be arranged inside the vehicle. The 3D packing solver and placement guide remain a separate next phase.

## Architecture

```
GigFit/
  GigFitApp.swift                    — @main app entry (SwiftUI)
  ContentView.swift                  — DELETED (dead code, unused)
  Models/
    ScanPoint.swift                  — 8-point label enum, codable vector, point source
    ScanDimensions.swift             — L×W×H + volume with unit conversion
    ScanConfidence.swift             — High/Medium/Low with inset percentages
    ScanSession.swift                — Full scan session model (Codable)
    CargoModels.swift                — Vehicle profiles, load sessions, packages, dimensions, status
  AR/
    ARScanCoordinator.swift          — State machine, crosshair, mesh rendering, all scanning logic
    ARScanView.swift                 — SwiftUI wrapper for ARSCNView + static crosshair
    ARSessionController.swift        — DELETED (dead code, unused)
    PointPlacementService.swift      — Plane raycasting + LiDAR depth unprojection
    MarkerEntityFactory.swift        — SceneKit markers, wireframe, measurement lines, transparent quads
  Geometry/
    VolumeCalculator.swift           — 6-tetrahedron decomposition volume
    DimensionExtractor.swift         — L×W×H from point cloud (face centroid method)
    CoordinateSystemBuilder.swift    — Right-handed coordinate system from points
    CalibrationService.swift         — One-distance tape-measure calibration
    ConfidenceScoring.swift          — Heuristic quality scoring (0–100)
    SafetyInsetCalculator.swift      — Conservative volume inset by confidence
    HexahedronMeshBuilder.swift      — Standalone SCNScene for 3D review
    CapacityCalculator.swift         — Loaded/remaining volume and percentage calculations
  Storage/
    ScanStore.swift                  — JSON persistence in documents directory
    CargoStore.swift                 — Versioned vehicle/load persistence in gigfit_cargo_v1.json
    PackageAssetStore.swift          — Validated, resized package screenshot storage
  Views/
    HomeView.swift                   — Saved scans, live loads, and scan/load entry points
    ScanInstructionsView.swift       — 4-step instruction cards before scanning
    ScanView.swift                   — Floor-calibrated expandable volume workflow
    ScanReviewView.swift             — 3D model + dimensions + confidence + save
    CalibrationView.swift            — Optional tape calibration (now has dismissAll hook)
    LiveLoadView.swift               — Live capacity dashboard and package status controls
    PackageEditorView.swift          — Screenshot, notes, quantity, and package measurements
  RoomPlan/
    RoomPlanCaptureController.swift  — RoomCaptureSession wrapper
    RoomPlanCaptureView.swift        — SwiftUI RoomCaptureView wrapper
    RoomPlanReviewView.swift         — QuickLook USDZ preview
    RoomPlanScanView.swift           — Entry point with LiDAR check
  Utilities/
    UnitFormatter.swift              — Imperial/metric display formatting
    SIMDHelpers.swift                — Centroid, distance, direction utilities
  Tests/
    VolumeCalculatorTests.swift
    SafetyInsetCalculatorTests.swift
    CalibrationServiceTests.swift
    CargoLoadTests.swift             — Capacity, persistence, delivery, and image-asset tests
```

## Performance notes

The app had recurrent freezing issues caused by heavy LiDAR mesh processing. The following controls are now in place:

| Component | Control |
|---|---|
| Crosshair targeting | One shared placement query every 6th frame (~10fps), only in manual/height modes |
| Ceiling detection | Only in polygon height mode, early-exits after 3 samples |
| Mesh rendering (sceneReconstruction) | Only enabled in `.auto` stage |
| Mesh geometry creation | Only in auto mode, sampled at 1/300th of faces |
| Mesh delegate updates | No-op in non-auto modes |
| Measurement line | Single solid SCNCylinder (was 10+ dashed segments) |
| Default stage | `.floor` (manual) — not `.auto` |

**Never re-enable sceneReconstruction globally.** It floods the main thread with ARMeshAnchor callbacks. If mesh rendering is needed, it must stay scoped to `.auto` mode only.

### Crosshair stability fix (July 21, 2026)

- `ARFrame.raycastQuery` requires normalized captured-image coordinates. Screen coordinates are now converted through the inverse ARKit display transform before every plane raycast and LiDAR depth lookup.
- Target priority is bounded plane geometry → visible LiDAR depth → estimated plane → infinite plane fallback. Hits outside 8 meters are rejected.
- Manual scanning uses its own advancing frame counter. The old auto-only counter stayed at zero in manual mode, causing two placement queries every camera frame despite the intended throttle.
- One placement result now drives both the surface-found UI and world target. The dynamic reticle is positioned directly instead of accumulating SceneKit movement actions.
- Polygon height targeting and the "Lock Height at Phone" control now use the polygon-height path correctly.

## VolumeScanStage enum

```
auto           — Continuous room scanning (heavy, LiDAR-only)
floor          — Place first corner (default)
width          — Place second corner, live rectangle preview
depth          — Place third corner, 3D base
height         — Raise phone to extrude
polygonFloor   — Multi-vertex floor tracing
polygonHeight  — Height for polygon mode
complete       — Volume locked
```

## Key interactions

- `skipCalibrationAndReview()` in ScanView computes dimensions + confidence + volume and shows ScanReviewView. No tape measure needed.
- `CalibrationView.dismissAll` closure lets parent dismiss the full scan flow.
- Confidence penalty for no calibration reduced from -30 to -10.
- RoomPlan framework uses auto-linking (`import RoomPlan`) — do NOT add it to pbxproj as a framework reference (causes embedding errors on App Store Connect).

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

The project currently contains 24 XCTest methods: 14 geometry/calibration tests and 10 cargo-load tests. On July 21, 2026, the full simulator suite reached the XCTest summary with 24 executed and 0 failures. ARKit and LiDAR behavior still requires physical-iPhone testing.

## Codemagic

Use workflow `gigfit-testflight`. Encrypted group `app_store_credentials` contains:

- `APP_STORE_CONNECT_PRIVATE_KEY`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `CERTIFICATE_PRIVATE_KEY`

Never commit or print their values. The App Store Connect key is locally stored at `/Users/suliemanvidal/Downloads/AuthKey_CB7RGT35JW.p8`. Active key ID: `CB7RGT35JW`.

An older unusable key named `GigFit Codemagic`, ID `75YD58U4CV`, has a lost one-time download. Revoke it only with the owner's explicit approval.

Tags matching `testflight-*` trigger the workflow automatically. Manual triggering (`Start new build` → branch `main` → `GigFit TestFlight`) is the fallback.

## Release procedure

1. Check `git status` and review the intended diff.
2. Run the device build and tests above.
3. Commit and push `main`.
4. Tag with `testflight-<desc>-<date>-<n>` and push.
5. In Codemagic, click **Start new build** (or wait for webhook).
6. Select branch `main` and workflow `GigFit TestFlight`.
7. Start without SSH/VNC unless debugging needs it.
8. Wait through IPA build, Publishing, and App Store distribution.
9. Verify in App Store Connect/TestFlight.
10. Add build to `GigFit Internal` group.
11. Confirm App Store Connect accepted the bundled export-compliance declaration; no manual encryption questionnaire should appear.
12. Open TestFlight on iPhone with `haidari.sulieman@gmail.com` and update GigFit.

Another app may occupy the only concurrent Codemagic builder. Leave GigFit queued instead of canceling unrelated work.

## Apple/TestFlight notes

- `GigFit/Resources/Info.plist` declares `ITSAppUsesNonExemptEncryption = false`. Apple should therefore record **No non-exempt encryption** from each uploaded binary without asking the questionnaire again, including for internal TestFlight builds.
- If App Store Connect shows **Missing Compliance** again, inspect the archived app's compiled `Info.plist` and verify that `ITSAppUsesNonExemptEncryption` is present as a Boolean `false` before changing the App Store Connect answer manually.
- Internal testing does not require external beta-review contact information.
- Build #21 uploaded successfully and App Store Connect finished processing it. Codemagic's later `422 External testing is not supported for build` message is only its attempted external beta-review submission being rejected for an internal-only binary; it is not an IPA upload or internal TestFlight failure.
- Codemagic may report missing Feedback Email and review-contact details after a successful upload. That affects external beta review, not internal testing.

## MVP progress and next phase

Implemented in the Roadie Live Load v1 slice:

- Individual item dimensions from manual entry or a saved GigFit item scan
- Saved vehicle profiles from measured cargo spaces
- Roadie/gig-app screenshots and notes attached to package entries
- Quantity, loaded/delivered status, removal, and a persistent running tally
- Live occupied/remaining volume and remaining-space percentage

Still planned for the **3D bin packing and placement phase**:

- A real 3D packing solver that tests orientation and physical arrangement, not only volume
- A rendered box arrangement inside the measured vehicle model
- Defensible "fits N more" predictions for a selected package size
- "Reorganize" to re-solve after packages are added, removed, or delivered
- Placement guidance for the next package and saved load history/catalog workflows
- Optional screenshot OCR/import assistance; v1 stores the screenshot but does not infer package dimensions from it

## Known risks

- Validate floor offset and LiDAR depth on the user's exact iPhone.
- Phone-on-floor calibration subtracts 2.5 cm from camera height. Tune against a tape measure.
- Move slowly in a well-lit space while tracking initializes.
- `VolumeCalculator` was fixed from an invalid five-tetrahedron decomposition to six. Do not revert it; regression tests cover boxes, sloped tops, and insets.
- The pbxproj file is sensitive to manual edits. Adding new files programmatically (Python) must preserve brace balance and reference chain (PBXFileReference → PBXBuildFile → PBXSourcesBuildPhase → PBXGroup).
- `ARSessionController.swift` and `ContentView.swift` were deleted — they are dead code. Do not restore them.

## Security

- Never request Apple passwords, two-factor codes, private keys, or certificates in chat.
- Let the user authenticate directly in Apple's UI.
- Never commit `.p8`, `.p12`, profiles, certificates, or API tokens.
- Do not revoke keys or certificates without explicit approval.
