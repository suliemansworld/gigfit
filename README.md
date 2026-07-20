# GigFit — Scan Space

For architecture, deployment, Apple/TestFlight setup, and agent continuation instructions, see [AGENT_HANDOFF.md](AGENT_HANDOFF.md).

Native iOS app that measures cargo spaces using ARKit and LiDAR when available. Calibrate a floor corner, set width and depth, then raise the phone to expand and lock a 3D volume for review and saving.

## Architecture

```
GigFit/
  GigFitApp.swift                    — @main app entry (SwiftUI)
  Models/
    ScanPoint.swift                  — 8-point label enum, codable vector, point source
    ScanDimensions.swift             — L×W×H + volume with unit conversion
    ScanConfidence.swift             — High/Medium/Low with inset percentages
    ScanSession.swift                — Full scan session model (Codable)
  AR/
    ARScanView.swift                 — SwiftUI wrapper for ARSCNView
    ARScanCoordinator.swift          — AR session delegate + point placement logic
    ARSessionController.swift        — AR session config management
    PointPlacementService.swift      — Plane raycasting + LiDAR depth placement
    MarkerEntityFactory.swift        — SceneKit marker + hexahedron wireframe nodes
  Geometry/
    VolumeCalculator.swift           — 6-tetrahedron decomposition volume
    DimensionExtractor.swift         — L×W×H from point cloud
    CoordinateSystemBuilder.swift    — Right-handed coordinate system from points
    CalibrationService.swift         — One-distance tape-measure calibration
    ConfidenceScoring.swift          — Heuristic quality scoring (0–100)
    SafetyInsetCalculator.swift      — Conservative volume inset by confidence
    HexahedronMeshBuilder.swift      — Standalone SCNScene for 3D review
  Storage/
    ScanStore.swift                  — JSON persistence in documents directory
  Views/
    HomeView.swift                   — Saved scans list + new scan button
    ScanInstructionsView.swift       — 4-step instruction cards before scanning
    ScanView.swift                   — Floor-calibrated expandable volume workflow
    ScanReviewView.swift             — 3D model + dimensions + confidence + save
  Utilities/
    UnitFormatter.swift              — Imperial/metric display formatting
    SIMDHelpers.swift                — Centroid, distance, direction utilities
  Tests/
    VolumeCalculatorTests.swift
    SafetyInsetCalculatorTests.swift
    CalibrationServiceTests.swift
```

## Setup on MacBook

1. Open Xcode → File → New → Project → iOS → App
2. Product Name: `GigFit`, Interface: SwiftUI, Language: Swift
3. Save the project to the cloned repo root (alongside the existing `GigFit/` folder)
4. Delete the auto-generated `ContentView.swift` and `GigFitApp.swift`
5. Drag the `GigFit/` folder from Finder into the Xcode project navigator
   - Check "Create groups" and "Add to target: GigFit"
6. In target settings → Info, add `NSCameraUsageDescription` key with value:
   "Camera access is required to scan cargo spaces and place boundary points."
7. Connect iPhone via USB, select it as the run destination
8. Press Cmd+R to build and run

## Requirements

- iOS 17.0+
- Xcode 15.0+
- iPhone with A12 Bionic or newer (ARKit 3 world tracking)
- Apple Developer account (free tier works for side-loading to your own device)
