import Foundation
import ARKit
import SceneKit
import SwiftUI

enum VolumeScanStage: Int, CaseIterable, Identifiable {
    case floor
    case width
    case depth
    case height
    case complete

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .floor: return "Set the floor"
        case .width: return "Set the width"
        case .depth: return "Set the depth"
        case .height: return "Raise to set height"
        case .complete: return "Volume captured"
        }
    }

    var instruction: String {
        switch self {
        case .floor: return "Put the phone over a floor corner, or aim the crosshair at the floor."
        case .width: return "Aim the crosshair along the floor at the opposite side."
        case .depth: return "Aim at the far floor edge. The rectangular base will appear."
        case .height: return "Raise the phone to the top of the space. The volume expands live."
        case .complete: return "Review the measured volume, or undo to adjust it."
        }
    }
}

/// Coordinates floor calibration, LiDAR-assisted placement, and live volume creation.
final class ARScanCoordinator: NSObject, ObservableObject, ARSCNViewDelegate, ARSessionDelegate {

    @Published var placedPoints: [ScanPoint] = []
    @Published var stage: VolumeScanStage = .floor
    @Published var isPlacementEnabled = true
    @Published var trackingState: ARCamera.TrackingState = .normal
    @Published var planeCount = 0
    @Published var sessionMessage = "Move the phone slowly so surfaces can be mapped."
    @Published var liveDimensions: SIMD3<Float> = .zero
    @Published var deviceHeightAboveFloor: Float = 0
    @Published var surfaceReady = false

    var onPointPlaced: ((ScanPoint) -> Void)?
    var onPointsChanged: (([ScanPoint]) -> Void)?
    var onAllPointsPlaced: (() -> Void)?

    var isLiDARAvailable: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
            || ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth)
    }

    private var sceneView: ARSCNView?
    private var previewNode: SCNNode?
    private var guideNode: SCNNode?
    private var floorOrigin: SIMD3<Float>?
    private var widthVector: SIMD3<Float>?
    private var depthVector: SIMD3<Float>?
    private var lockedHeight: Float?
    private var floorSource: PointSource = .estimatedPlane
    private var upperSource: PointSource = .estimatedPlane
    private var lastPreviewUpdate: TimeInterval = 0

    func attach(to sceneView: ARSCNView) {
        self.sceneView = sceneView
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.scene = SCNScene()
    }

    func startSession() {
        guard let sceneView else { return }
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }


    func pauseSession() {
        sceneView?.session.pause()
    }
    func resetSession() {
        floorOrigin = nil
        widthVector = nil
        depthVector = nil
        lockedHeight = nil
        placedPoints = []
        stage = .floor
        isPlacementEnabled = true
        liveDimensions = .zero
        deviceHeightAboveFloor = 0
        removeVisuals()
        onPointsChanged?([])
        startSession()
    }

    func placeAtCrosshair() {
        guard let sceneView else { return }
        let point = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY - 40)
        handleTap(at: point)
    }

    func handleTap(at point: CGPoint) {
        guard isPlacementEnabled,
              stage != .complete,
              let sceneView,
              let frame = sceneView.session.currentFrame else { return }

        let alignment: ARRaycastQuery.TargetAlignment = stage == .height ? .any : .horizontal
        let orientation = sceneView.window?.windowScene?.interfaceOrientation ?? .portrait
        guard let result = PointPlacementService.place(
            at: point,
            in: frame,
            session: sceneView.session,
            viewportSize: sceneView.bounds.size,
            orientation: orientation,
            alignment: alignment
        ) else {
            sessionMessage = stage == .floor
                ? "No floor found yet. Move slowly, or use Phone on Floor."
                : "No real surface or LiDAR depth found at the crosshair."
            return
        }

        switch stage {
        case .floor:
            setFloor(result.worldPosition, source: result.source)
        case .width:
            setWidth(result.worldPosition)
        case .depth:
            setDepth(result.worldPosition)
        case .height:
            lockHeight(worldY: result.worldPosition.y, source: result.source)
        case .complete:
            break
        }
    }

    /// Calibrates the floor from the phone's current physical position.
    func calibrateFloorAtDevice() {
        guard stage == .floor,
              let frame = sceneView?.session.currentFrame,
              case .normal = frame.camera.trackingState else {
            sessionMessage = "Wait for tracking to become ready, then try again."
            return
        }
        let camera = frame.camera.transform.columns.3
        setFloor(SIMD3<Float>(camera.x, camera.y - 0.025, camera.z), source: .estimatedPlane)
    }

    func lockHeightAtDevice() {
        guard stage == .height,
              let frame = sceneView?.session.currentFrame else { return }
        lockHeight(worldY: frame.camera.transform.columns.3.y, source: isLiDARAvailable ? .lidarDepth : .estimatedPlane)
    }

    func undoLastPoint() {
        switch stage {
        case .complete:
            placedPoints = []
            onPointsChanged?([])
            lockedHeight = nil
            stage = .height
            isPlacementEnabled = true
            updateLiveHeightFromDevice()
        case .height:
            depthVector = nil
            stage = .depth
            liveDimensions.z = 0
            refreshPreview()
        case .depth:
            widthVector = nil
            stage = .width
            liveDimensions.x = 0
            refreshPreview()
        case .width:
            floorOrigin = nil
            stage = .floor
            liveDimensions = .zero
            removeVisuals()
        case .floor:
            return
        }
        sessionMessage = stage.instruction
    }

    private func setFloor(_ position: SIMD3<Float>, source: PointSource) {
        floorOrigin = position
        floorSource = source
        stage = .width
        sessionMessage = stage.instruction
        refreshPreview()
    }

    private func setWidth(_ position: SIMD3<Float>) {
        guard let floorOrigin else { return }
        var vector = position - floorOrigin
        vector.y = 0
        guard simd_length(vector) >= 0.15 else {
            sessionMessage = "Move the target at least 6 inches from the first corner."
            return
        }
        widthVector = vector
        liveDimensions.x = simd_length(vector)
        stage = .depth
        sessionMessage = stage.instruction
        refreshPreview()
    }

    private func setDepth(_ position: SIMD3<Float>) {
        guard let floorOrigin, let widthVector else { return }
        let widthDirection = simd_normalize(widthVector)
        let perpendicular = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), widthDirection))
        let signedDepth = simd_dot(position - floorOrigin, perpendicular)
        guard abs(signedDepth) >= 0.15 else {
            sessionMessage = "Aim farther from the width edge to create the base."
            return
        }
        depthVector = perpendicular * signedDepth
        liveDimensions.z = abs(signedDepth)
        stage = .height
        sessionMessage = stage.instruction
        updateLiveHeightFromDevice()
    }

    private func lockHeight(worldY: Float, source: PointSource) {
        guard let floorOrigin else { return }
        let height = worldY - floorOrigin.y
        guard height >= 0.15 else {
            sessionMessage = "Raise the phone at least 6 inches above the calibrated floor."
            return
        }
        lockedHeight = height
        upperSource = source
        liveDimensions.y = height
        commitVolume(height: height)
    }

    private func commitVolume(height: Float) {
        guard let corners = volumeCorners(height: height) else { return }
        let ordered = ScanPointLabel.allCases.compactMap { label -> ScanPoint? in
            guard let position = corners[label] else { return nil }
            let source = ScanPointLabel.floorLabels.contains(label) ? floorSource : upperSource
            return ScanPoint(label: label, position: CodableVector3(position), source: source)
        }
        guard ordered.count == 8 else { return }

        placedPoints = ordered
        ordered.forEach { onPointPlaced?($0) }
        onPointsChanged?(ordered)
        stage = .complete
        isPlacementEnabled = false
        sessionMessage = "Volume locked. Continue to review measurements."
        refreshPreview()
        onAllPointsPlaced?()
    }

    private func volumeCorners(height: Float) -> [ScanPointLabel: SIMD3<Float>]? {
        guard let origin = floorOrigin,
              let width = widthVector,
              let depth = depthVector else { return nil }
        let right = origin + width
        let frontLeft = origin + depth
        let frontRight = right + depth
        let up = SIMD3<Float>(0, height, 0)
        return [
            .rearLeftFloor: origin,
            .rearRightFloor: right,
            .frontRightFloor: frontRight,
            .frontLeftFloor: frontLeft,
            .rearLeftUpper: origin + up,
            .rearRightUpper: right + up,
            .frontRightUpper: frontRight + up,
            .frontLeftUpper: frontLeft + up
        ]
    }

    private func updateLiveHeightFromDevice() {
        guard stage == .height,
              let origin = floorOrigin,
              let cameraY = sceneView?.session.currentFrame?.camera.transform.columns.3.y else { return }
        let height = max(0.15, cameraY - origin.y)
        deviceHeightAboveFloor = max(0, cameraY - origin.y)
        liveDimensions.y = height
        refreshPreview(height: height)
    }

    private func refreshPreview(height: Float? = nil) {
        previewNode?.removeFromParentNode()
        previewNode = nil
        guideNode?.removeFromParentNode()
        guideNode = nil

        if let origin = floorOrigin, let width = widthVector, depthVector == nil {
            let guide = MarkerEntityFactory.createMeasurementLine(from: origin, to: origin + width)
            sceneView?.scene.rootNode.addChildNode(guide)
            guideNode = guide
        } else if let origin = floorOrigin, widthVector == nil {
            let marker = MarkerEntityFactory.createMarker(label: .rearLeftFloor,
                                                           position: SCNVector3FromSIMD(origin))
            sceneView?.scene.rootNode.addChildNode(marker)
            guideNode = marker
        }

        let previewHeight = height ?? lockedHeight ?? max(liveDimensions.y, 0.15)
        guard let corners = volumeCorners(height: previewHeight) else { return }
        let sceneCorners = Dictionary(uniqueKeysWithValues: corners.map { ($0.key, SCNVector3FromSIMD($0.value)) })
        let node = MarkerEntityFactory.createHexahedronWireframe(corners: sceneCorners)
        sceneView?.scene.rootNode.addChildNode(node)
        previewNode = node
    }

    private func removeVisuals() {
        previewNode?.removeFromParentNode()
        guideNode?.removeFromParentNode()
        previewNode = nil
        guideNode = nil
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let now = frame.timestamp
        DispatchQueue.main.async {
            self.trackingState = frame.camera.trackingState
            self.surfaceReady = self.planeCount > 0 || frame.sceneDepth != nil || frame.smoothedSceneDepth != nil
            if self.stage == .height, now - self.lastPreviewUpdate > 0.08 {
                self.lastPreviewUpdate = now
                self.updateLiveHeightFromDevice()
            } else if case .limited(let reason) = frame.camera.trackingState {
                self.sessionMessage = "Tracking limited: \(self.reasonString(reason))"
            }
        }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let added = anchors.compactMap { $0 as? ARPlaneAnchor }.count
        DispatchQueue.main.async {
            self.planeCount += added
            self.surfaceReady = self.planeCount > 0 || self.isLiDARAvailable
            if added > 0, self.stage == .floor {
                self.sessionMessage = "Floor detected. Set the first corner."
            }
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let removed = anchors.compactMap { $0 as? ARPlaneAnchor }.count
        DispatchQueue.main.async {
            self.planeCount = max(0, self.planeCount - removed)
        }
    }

    private func reasonString(_ reason: ARCamera.TrackingState.Reason) -> String {
        switch reason {
        case .excessiveMotion: return "Move the phone more slowly"
        case .insufficientFeatures: return "Point at a textured, well-lit surface"
        case .relocalizing: return "Relocalizing"
        default: return "Tracking is not ready"
        }
    }
}

func SCNVector3FromSIMD(_ vector: SIMD3<Float>) -> SCNVector3 {
    SCNVector3(vector.x, vector.y, vector.z)
}

func SCNVector3ToSIMD(_ vector: SCNVector3) -> SIMD3<Float> {
    SIMD3<Float>(vector.x, vector.y, vector.z)
}
