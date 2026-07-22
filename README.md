# GigFit — Scan Space

For architecture, deployment, Apple/TestFlight setup, and agent continuation instructions, see [AGENT_HANDOFF.md](AGENT_HANDOFF.md).

Native iOS app that measures cargo spaces using ARKit and LiDAR when available, then turns those measurements into persistent live-load capacity tracking for Roadie and other delivery work. Drivers can attach a gig-app screenshot to a package, enter or reuse its measurements, see remaining cargo volume update as packages are loaded or delivered, and generate a conservative rectangular packing plan.

## Architecture

```
GigFit/
  GigFitApp.swift                    — @main app entry (SwiftUI)
  Models/
    ScanPoint.swift                  — 8-point label enum, codable vector, point source
    ScanDimensions.swift             — L×W×H + volume with unit conversion
    ScanConfidence.swift             — High/Medium/Low with inset percentages
    ScanSession.swift                — Full scan session model (Codable)
    CargoModels.swift                — Vehicle, load-session, and package models
  AR/
    ARScanView.swift                 — SwiftUI wrapper for ARSCNView
    ARScanCoordinator.swift          — AR session delegate + point placement logic
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
    CapacityCalculator.swift         — Remaining-space calculations
    PackingSolver.swift              — Bounded best-found 3D rectangular packing
  Storage/
    ScanStore.swift                  — JSON persistence in documents directory
    CargoStore.swift                 — Vehicle profiles and live-load persistence
    PackageAssetStore.swift          — Package screenshot validation and storage
  Views/
    HomeView.swift                   — Saved scans, live loads, and entry points
    ScanInstructionsView.swift       — 4-step instruction cards before scanning
    ScanView.swift                   — Floor-calibrated expandable volume workflow
    ScanReviewView.swift             — 3D model + dimensions + confidence + save
    LiveLoadView.swift               — Capacity dashboard and package status controls
    PackingPlanView.swift            — Packing summary, diagrams, steps, and re-solve UI
    PackageEditorView.swift          — Screenshot, notes, quantity, and dimensions
  Utilities/
    UnitFormatter.swift              — Imperial/metric display formatting
    SIMDHelpers.swift                — Centroid, distance, direction utilities
  Tests/
    VolumeCalculatorTests.swift
    SafetyInsetCalculatorTests.swift
    CalibrationServiceTests.swift
    CargoLoadTests.swift
    PackingSolverTests.swift
```

## Roadie packing plan

The packing phase uses a deterministic, bounded heuristic to place loaded package quantities in a conservative rectangular vehicle envelope. Delivered packages are excluded. The solver tries unique 90-degree rotations, enforces container bounds and non-overlap, requires supported stacking surfaces, and keeps the best layout it finds across several item orderings. It analyzes up to 72 loaded package copies on-device and explicitly labels any remainder as not analyzed.

The live-load dashboard shows placed/unplaced status and how many additional placements the best-found plan discovered for a selected measured package. **View Plan** provides numbered isometric and top-down placement guidance from the rear cargo door; **Reorganize** tries another deterministic layout variant.

This is a conservative rectangular estimate, not a guarantee or proof of optimal packing. Irregular vehicle geometry such as wheel wells and curved trim is not modeled, and neither are weight distribution, tie-downs, package fragility, stacking strength, door clearance, or safe driver visibility. Verify the real load before driving.

The project contains 34 XCTest methods, including 10 focused packing-solver tests for rotations, quantity handling, spatial failures, support, bounds, overlap, mobile limits, fit counts, and determinism.

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
