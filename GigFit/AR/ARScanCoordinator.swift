import Foundation
import ARKit
import SceneKit
import SwiftUI

/// ARSCNViewDelegate — manages the AR scene, hit-testing, and point placement.
final class ARScanCoordinator: NSObject, ObservableObject, ARSCNViewDelegate, ARSessionDelegate {

    @Published var placedPoints: [ScanPoint] = []
    @Published var currentLabel: ScanPointLabel = .rearLeftFloor
    @Published var isPlacementEnabled = true
    @Published var trackingState: ARCamera.TrackingState = .normal
    @Published var planeCount: Int = 0
    @Published var sessionMessage: String = "Move your device to detect surfaces"

    var onPointPlaced: ((ScanPoint) -> Void)?
    var onAllPointsPlaced: (() -> Void)?

    private var sceneView: ARSCNView?
    private var hexahedronNode: SCNNode?

    // MARK: — Setup —

    func attach(to sceneView: ARSCNView) {
        self.sceneView = sceneView
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true

        let scene = SCNScene()
        sceneView.scene = scene
    }

    func startSession() {
        guard let sceneView else { return }
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.sceneReconstruction = .meshWithClassification
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func resetSession() {
        placedPoints.removeAll()
        currentLabel = .rearLeftFloor
        hexahedronNode?.removeFromParentNode()
        hexahedronNode = nil
        startSession()
    }

    // MARK: — Point Placement —

    func handleTap(at point: CGPoint) {
        guard isPlacementEnabled,
              let sceneView,
              let frame = sceneView.session.currentFrame else { return }

        guard let result = PointPlacementService.place(at: point, in: frame,
                                                        session: sceneView.session) else {
            sessionMessage = "No surface detected. Try moving the device."
            return
        }

        let scanPoint = ScanPoint(label: currentLabel,
                                   position: CodableVector3(result.worldPosition),
                                   source: result.source)

        // Add visual marker
        let marker = MarkerEntityFactory.createMarker(label: currentLabel,
                                                       position: SCNVector3FromSIMD(result.worldPosition))
        marker.name = "point_\(currentLabel.rawValue)"
        sceneView.scene.rootNode.addChildNode(marker)

        // Add anchored node via ARAnchor for persistence
        let anchor = ARAnchor(name: currentLabel.rawValue,
                               transform: simd_float4x4(translation: result.worldPosition))
        sceneView.session.add(anchor: anchor)

        placedPoints.append(scanPoint)
        onPointPlaced?(scanPoint)

        // Advance to next label
        let allLabels = ScanPointLabel.allCases
        if let currentIdx = allLabels.firstIndex(of: currentLabel),
           currentIdx + 1 < allLabels.count {
            currentLabel = allLabels[currentIdx + 1]
            let num = currentIdx + 2
            sessionMessage = "Point \(num)/8: \(currentLabel.instruction)"
        } else {
            isPlacementEnabled = false
            sessionMessage = "All 8 points placed. Review your scan."
            buildHexahedron()
            onAllPointsPlaced?()
        }
    }

    func undoLastPoint() {
        guard let lastPoint = placedPoints.last else { return }
        placedPoints.removeLast()
        currentLabel = lastPoint.label

        // Remove visual marker
        if let sceneView {
            sceneView.scene.rootNode.childNodes
                .filter { $0.name == "point_\(lastPoint.label.rawValue)" }
                .forEach { $0.removeFromParentNode() }
        }

        // Update hexahedron if all points had been placed
        if placedPoints.count == 7 {
            hexahedronNode?.removeFromParentNode()
            hexahedronNode = nil
            isPlacementEnabled = true
        }

        sessionMessage = "Point \(placedPoints.count + 1)/8: \(currentLabel.instruction)"
    }

    // MARK: — Hexahedron —

    func buildHexahedron() {
        guard placedPoints.count == 8 else { return }
        hexahedronNode?.removeFromParentNode()

        var corners: [ScanPointLabel: SCNVector3] = [:]
        for point in placedPoints {
            corners[point.label] = SCNVector3FromSIMD(point.position.simd)
        }

        let wireframe = MarkerEntityFactory.createHexahedronWireframe(corners: corners)
        sceneView?.scene.rootNode.addChildNode(wireframe)
        hexahedronNode = wireframe
    }

    // MARK: — ARSCNViewDelegate & ARSessionDelegate —

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Update tracking state
        DispatchQueue.main.async {
            self.trackingState = frame.camera.trackingState
            switch frame.camera.trackingState {
            case .normal:
                if self.placedPoints.isEmpty {
                    self.sessionMessage = "Move your device to detect surfaces"
                }
            case .limited(let reason):
                self.sessionMessage = "Tracking limited: \(self.reasonString(reason))"
            case .notAvailable:
                self.sessionMessage = "Tracking not available"
            }
        }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let planeAnchors = anchors.compactMap { $0 as? ARPlaneAnchor }
        DispatchQueue.main.async {
            self.planeCount += planeAnchors.count
            if self.planeCount > 0 && self.placedPoints.isEmpty {
                self.sessionMessage = "Surfaces detected. Tap to place points."
            }
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let planeAnchors = anchors.compactMap { $0 as? ARPlaneAnchor }
        DispatchQueue.main.async {
            self.planeCount = max(0, self.planeCount - planeAnchors.count)
        }
    }

    // Anchor nodes for placed points
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let name = anchor.name,
              let label = ScanPointLabel(rawValue: name) else { return nil }
        let marker = MarkerEntityFactory.createMarker(label: label,
                                                       position: SCNVector3Zero)
        return marker
    }

    private func reasonString(_ reason: ARCamera.TrackingState.Reason) -> String {
        switch reason {
        case .excessiveMotion: return "Too much motion"
        case .insufficientFeatures: return "Not enough visual features"
        case .relocalizing: return "Relocalizing..."
        default: return "Unknown"
        }
    }
}

// MARK: — SIMD → SCNVector3 helpers —

func SCNVector3FromSIMD(_ v: SIMD3<Float>) -> SCNVector3 {
    SCNVector3(v.x, v.y, v.z)
}

func SCNVector3ToSIMD(_ v: SCNVector3) -> SIMD3<Float> {
    SIMD3<Float>(v.x, v.y, v.z)
}

extension simd_float4x4 {
    init(translation: SIMD3<Float>) {
        self.init(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        ))
    }
}
