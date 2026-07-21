import Foundation
import ARKit
import SceneKit
import SwiftUI

enum VolumeScanStage: Int, CaseIterable, Identifiable {
    case auto
    case floor
    case width
    case depth
    case height
    case polygonFloor
    case polygonHeight
    case complete

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto Room Scan"
        case .floor: return "Set the floor"
        case .width: return "Set the width"
        case .depth: return "Set the depth"
        case .height: return "Raise to set height"
        case .polygonFloor: return "Trace the floor"
        case .polygonHeight: return "Raise to set height"
        case .complete: return "Volume captured"
        }
    }

    var instruction: String {
        switch self {
        case .auto: return "Pan the phone around the room. Walls extend the box automatically."
        case .floor: return "Put the phone over a floor corner, or aim the crosshair at the floor."
        case .width: return "Aim the crosshair along the floor at the opposite side."
        case .depth: return "Aim at the far floor edge. The rectangular base will appear."
        case .height: return "Raise the phone to the top of the space. The volume expands live."
        case .polygonFloor: return "Tap along the floor perimeter. Snaps to detected walls."
        case .polygonHeight: return "Raise the phone to the top of the space. The volume expands live."
        case .complete: return "Review the measured volume, or undo to adjust it."
        }
    }
}

/// Coordinates floor calibration, LiDAR-assisted placement, and live volume creation.
final class ARScanCoordinator: NSObject, ObservableObject, ARSCNViewDelegate, ARSessionDelegate {

    @Published var placedPoints: [ScanPoint] = []
    @Published var stage: VolumeScanStage = .auto
    @Published var isPlacementEnabled = true
    @Published var trackingState: ARCamera.TrackingState = .normal
    @Published var planeCount = 0
    @Published var sessionMessage = "Move the phone slowly so surfaces can be mapped."
    @Published var crosshairSurfaceFound = false
    @Published var liveDimensions: SIMD3<Float> = .zero
    @Published var deviceHeightAboveFloor: Float = 0
    @Published var surfaceReady = false
    @Published var autoRoomReady = false
    @Published var meshActive = false
    @Published var crosshairHit = false
    @Published var crosshairPosition: SIMD3<Float>? = nil

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

    // Auto-room state
    private var roomMinBounds: SIMD3<Float>?
    private var roomMaxBounds: SIMD3<Float>?
    private var sampledFrames: Int = 0
    private var wallDistanceLabels: [SCNNode] = []
    private var crosshairNode: SCNNode?
    private var meshNodes: [UUID: SCNNode] = [:]
    private var polygonVertices: [SIMD3<Float>] = []
    private var polygonClosed = false
    private var polygonFloorY: Float = 0

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
        stage = .auto
        isPlacementEnabled = true
        liveDimensions = .zero
        deviceHeightAboveFloor = 0
        autoRoomReady = false
        roomMinBounds = nil
        roomMaxBounds = nil
        sampledFrames = 0
        polygonVertices = []
        polygonClosed = false
        removeAutoLabels()
        removeCrosshairNode()
        removeMeshNodes()
        removeVisuals()
        onPointsChanged?([])
        startSession()
    }

    /// Switch to manual point-placement mode.
    func switchToManual() {
        stage = .floor
        roomMinBounds = nil
        roomMaxBounds = nil
        sampledFrames = 0
        polygonVertices = []
        polygonClosed = false
        autoRoomReady = false
        removeAutoLabels()
        removeCrosshairNode()
        removeCrosshairNode()
        removeMeshNodes()
        removeVisuals()
        sessionMessage = stage.instruction
    }

    /// Lock the auto-detected room volume.
    func lockAutoRoom() {
        guard let minBounds = roomMinBounds,
              let maxBounds = roomMaxBounds,
              sampledFrames > 5 else {
            sessionMessage = "Keep panning — need more wall data before locking."
            return
        }

        let center = (minBounds + maxBounds) / 2
        let size = maxBounds - minBounds

        floorOrigin = SIMD3<Float>(center.x, minBounds.y, center.z)
        widthVector = SIMD3<Float>(size.x, 0, 0)
        depthVector = SIMD3<Float>(0, 0, size.z)
        lockedHeight = size.y
        floorSource = isLiDARAvailable ? .lidarDepth : .existingPlaneGeometry
        upperSource = isLiDARAvailable ? .lidarDepth : .existingPlaneGeometry
        liveDimensions = SIMD3<Float>(abs(size.x), size.y, abs(size.z))

        commitVolume(height: size.y)
        removeAutoLabels()
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
        case .polygonFloor:
            addPolygonVertex(at: result.worldPosition)
        case .polygonHeight:
            lockPolygonHeight(worldY: result.worldPosition.y, source: result.source)
        case .auto: break
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
        case .polygonHeight:
            polygonClosed = false
            stage = .polygonFloor
            liveDimensions = .zero
            removeVisuals()
            refreshPolygonPreview()
        case .polygonFloor:
            if !polygonVertices.isEmpty {
                polygonVertices.removeLast()
                polygonClosed = false
                refreshPolygonPreview()
            }
            return
        case .floor, .auto:
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

    // MARK: — Auto Room Scanning —

    private func expandRoomBounds(worldPoint: SIMD3<Float>) {
        if roomMinBounds == nil {
            roomMinBounds = worldPoint
            roomMaxBounds = worldPoint
        } else {
            roomMinBounds = simd_min(roomMinBounds!, worldPoint)
            roomMaxBounds = simd_max(roomMaxBounds!, worldPoint)
        }
    }

    private func expandRoomFromPlane(_ anchor: ARPlaneAnchor) {
        let transform = anchor.transform
        let center = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let extent = anchor.extent

        // Sample the 4 corners and center of the plane
        let halfX = extent.x / 2
        let halfZ = extent.z / 2
        let corners: [SIMD3<Float>] = [
            SIMD3<Float>(center.x + halfX, center.y, center.z + halfZ),
            SIMD3<Float>(center.x + halfX, center.y, center.z - halfZ),
            SIMD3<Float>(center.x - halfX, center.y, center.z + halfZ),
            SIMD3<Float>(center.x - halfX, center.y, center.z - halfZ),
            center
        ]

        for corner in corners {
            // Transform from local to world space
            let worldPoint = SIMD3<Float>(
                transform.columns.0.x * corner.x + transform.columns.1.x * corner.y + transform.columns.2.x * corner.z + transform.columns.3.x,
                transform.columns.0.y * corner.x + transform.columns.1.y * corner.y + transform.columns.2.y * corner.z + transform.columns.3.y,
                transform.columns.0.z * corner.x + transform.columns.1.z * corner.y + transform.columns.2.z * corner.z + transform.columns.3.z
            )
            expandRoomBounds(worldPoint: worldPoint)
        }
    }

    private func sampleMeshVertices(from meshAnchor: ARMeshAnchor) {
        let geometry = meshAnchor.geometry
        let vertices = geometry.vertices
        let faces = geometry.faces
        let classification = geometry.classification

        let vertexCount = vertices.count
        let faceCount = faces.count
        guard vertexCount > 0, faceCount > 0 else { return }

        let transform = meshAnchor.transform

        // Access raw vertex buffer
        let vertexBuffer = vertices.buffer.contents().assumingMemoryBound(to: (Float, Float, Float).self)
        let faceBuffer = faces.buffer.contents().assumingMemoryBound(to: UInt8.self)
        let faceStride = MemoryLayout<Int32>.stride * 3

        let classificationBuffer = classification?.buffer.contents().assumingMemoryBound(to: UInt8.self)

        // Sample every Nth face to keep performance reasonable
        let sampleStride = max(1, faceCount / 200)

        for faceIdx in stride(from: 0, to: faceCount, by: sampleStride) {
            // Check classification: only expand for wall, floor, ceiling
            if let classBuf = classificationBuffer {
                let classByte = classBuf[faceIdx * MemoryLayout<UInt8>.stride]
                // ARMeshClassification values: 1=wall, 2=floor, 3=ceiling
                guard classByte >= 1 && classByte <= 3 else { continue }
            }

            // Get 3 vertex indices for this face
            let idx0 = Int(faceBuffer[faceIdx * faceStride])
            let idx1 = Int(faceBuffer[faceIdx * faceStride + MemoryLayout<Int32>.stride])
            let idx2 = Int(faceBuffer[faceIdx * faceStride + MemoryLayout<Int32>.stride * 2])

            guard idx0 < vertexCount, idx1 < vertexCount, idx2 < vertexCount else { continue }

            for idx in [idx0, idx1, idx2] {
                let v = vertexBuffer[idx]
                let localPoint = SIMD4<Float>(v.0, v.1, v.2, 1)
                let worldPoint4 = transform * localPoint
                let worldPoint = SIMD3<Float>(worldPoint4.x, worldPoint4.y, worldPoint4.z)
                expandRoomBounds(worldPoint: worldPoint)
            }
        }
    }

    private func refreshAutoPreview() {
        previewNode?.removeFromParentNode()
        previewNode = nil

        guard let minBounds = roomMinBounds,
              let maxBounds = roomMaxBounds else { return }

        let size = maxBounds - minBounds
        guard abs(size.x) >= 0.15, abs(size.z) >= 0.15, size.y >= 0.15 else { return }

        liveDimensions = SIMD3<Float>(abs(size.x), size.y, abs(size.z))

        // Build the 8 corners from bounds
        let origin = SIMD3<Float>(minBounds.x, minBounds.y, minBounds.z)
        let width = SIMD3<Float>(size.x, 0, 0)
        let depth = SIMD3<Float>(0, 0, size.z)
        let height = size.y

        let corners: [ScanPointLabel: SIMD3<Float>] = [
            .rearLeftFloor: origin,
            .rearRightFloor: origin + width,
            .frontRightFloor: origin + width + depth,
            .frontLeftFloor: origin + depth,
            .rearLeftUpper: origin + SIMD3<Float>(0, height, 0),
            .rearRightUpper: origin + width + SIMD3<Float>(0, height, 0),
            .frontRightUpper: origin + width + depth + SIMD3<Float>(0, height, 0),
            .frontLeftUpper: origin + depth + SIMD3<Float>(0, height, 0)
        ]

        let sceneCorners = Dictionary(uniqueKeysWithValues: corners.map { ($0.key, SCNVector3FromSIMD($0.value)) })
        let node = MarkerEntityFactory.createHexahedronWireframe(corners: sceneCorners)
        sceneView?.scene.rootNode.addChildNode(node)
        previewNode = node

        // Wall distance labels
        removeAutoLabels()
        let widthFt = UnitFormatter.formatFeetAndInches(Double(abs(size.x)))
        let depthFt = UnitFormatter.formatFeetAndInches(Double(abs(size.z)))
        let heightFt = UnitFormatter.formatFeetAndInches(Double(size.y))

        let labels: [(text: String, pos: SIMD3<Float>)] = [
            (widthFt, origin + width / 2 + SIMD3<Float>(0, size.y / 2, 0)),
            (depthFt, origin + width + depth / 2 + SIMD3<Float>(0, size.y / 2, 0)),
            (heightFt, origin + width / 2 + depth / 2 + SIMD3<Float>(0, size.y, 0))
        ]

        for (text, pos) in labels {
            let label = MarkerEntityFactory.createLabel(text: text, at: SCNVector3FromSIMD(pos))
            label.name = "auto_label"
            sceneView?.scene.rootNode.addChildNode(label)
            wallDistanceLabels.append(label)
        }
    }

    private func removeAutoLabels() {
        for node in wallDistanceLabels {
            node.removeFromParentNode()
        }
        wallDistanceLabels.removeAll()
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



    // MARK: — Crosshair Surface Detection —

    private func updateCrosshair(from frame: ARFrame) {
        guard let sv = self.sceneView, sv.bounds.width > 0, self.stage != .complete else { return }
        let point = CGPoint(x: sv.bounds.midX, y: sv.bounds.midY - 40)
        let orientation = sv.window?.windowScene?.interfaceOrientation ?? .portrait
        let alignment: ARRaycastQuery.TargetAlignment = (self.stage == .height || self.stage == .polygonHeight) ? .any : .horizontal

        if let result = PointPlacementService.place(
            at: point, in: frame, session: sv.session,
            viewportSize: sv.bounds.size, orientation: orientation, alignment: alignment
        ) {
            self.crosshairHit = true
            self.crosshairPosition = result.worldPosition
            if self.stage != .complete && self.sessionMessage == self.stage.instruction {
                self.sessionMessage = "Surface found! Tap to place point."
            }
            let pos = SCNVector3FromSIMD(result.worldPosition)
            if self.crosshairNode == nil {
                self.crosshairNode = self.makeCrosshairNode()
                sv.scene.rootNode.addChildNode(self.crosshairNode!)
            }
            self.crosshairNode?.position = pos
            self.crosshairNode?.isHidden = false
            // Orient flat (parallel to floor)
            self.crosshairNode?.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        } else {
            self.crosshairHit = false
            self.crosshairNode?.isHidden = true
        }
    }

    private func makeCrosshairNode() -> SCNNode {
        let parent = SCNNode()
        parent.name = "dynamic_crosshair"

        let ring = SCNTorus(ringRadius: 0.035, pipeRadius: 0.002)
        ring.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.85)
        ring.firstMaterial?.lightingModel = .constant
        parent.addChildNode(SCNNode(geometry: ring))

        let dot = SCNSphere(radius: 0.007)
        dot.firstMaterial?.diffuse.contents = UIColor.white
        dot.firstMaterial?.lightingModel = .constant
        parent.addChildNode(SCNNode(geometry: dot))

        return parent
    }

    private func removeCrosshairNode() {
        crosshairNode?.removeFromParentNode()
        crosshairNode = nil
        crosshairHit = false
    }

    // MARK: — Mesh Rendering —

    private func removeMeshNodes() {
        for (_, node) in meshNodes {
            node.removeFromParentNode()
        }
        meshNodes.removeAll()
    }

    private func updateMeshNode(_ node: SCNNode, from geometry: ARMeshGeometry) {
        guard let newGeo = createMeshSCNGeometry(from: geometry) else { return }
        node.geometry = newGeo
    }

    private func createMeshSCNGeometry(from meshGeometry: ARMeshGeometry) -> SCNGeometry? {
        let vertices = meshGeometry.vertices
        let faces = meshGeometry.faces
        let classification = meshGeometry.classification
        let vertexCount = vertices.count
        let faceCount = faces.count

        guard vertexCount > 0, faceCount > 0 else { return nil }

        let vertexBuffer = vertices.buffer.contents().assumingMemoryBound(to: (Float, Float, Float).self)
        let faceBuffer = faces.buffer.contents().assumingMemoryBound(to: UInt8.self)
        let idxStride = MemoryLayout<Int32>.stride
        let faceStride = idxStride * 3

        let clsBuffer = classification?.buffer.contents().assumingMemoryBound(to: UInt8.self)

        var allVertices: [SCNVector3] = []
        var allIndices: [Int32] = []
        var allColors: [SCNVector3] = []

        for faceIdx in 0..<faceCount {
            let i0 = Int(faceBuffer[faceIdx * faceStride])
            let i1 = Int(faceBuffer[faceIdx * faceStride + idxStride])
            let i2 = Int(faceBuffer[faceIdx * faceStride + idxStride * 2])

            guard i0 < vertexCount, i1 < vertexCount, i2 < vertexCount else { continue }

            let baseIdx = Int32(allVertices.count)
            allIndices.append(contentsOf: [baseIdx, baseIdx + 1, baseIdx + 2])

            for i in [i0, i1, i2] {
                let v = vertexBuffer[i]
                allVertices.append(SCNVector3(v.0, v.1, v.2))
            }

            // Color by classification if available
            var color = SCNVector3(0.6, 0.6, 0.6) // default gray
            if let clsBuf = clsBuffer {
                let cls = clsBuf[faceIdx * MemoryLayout<UInt8>.stride]
                switch cls {
                case 1: color = SCNVector3(0.4, 0.8, 0.4)  // wall: green
                case 2: color = SCNVector3(0.3, 0.5, 1.0)  // floor: blue
                case 3: color = SCNVector3(1.0, 0.4, 0.4)  // ceiling: red
                default: break
                }
            }
            allColors.append(contentsOf: [color, color, color])
        }

        guard !allVertices.isEmpty else { return nil }

        let vertData = Data(bytes: allVertices, count: allVertices.count * MemoryLayout<SCNVector3>.stride)
        let vertexSrc = SCNGeometrySource(data: vertData,
                                          semantic: .vertex,
                                          vectorCount: allVertices.count,
                                          usesFloatComponents: true,
                                          componentsPerVector: 3,
                                          bytesPerComponent: MemoryLayout<Float>.stride,
                                          dataOffset: 0,
                                          dataStride: MemoryLayout<SCNVector3>.stride)

        let colorData = Data(bytes: allColors, count: allColors.count * MemoryLayout<SCNVector3>.stride)
        let colorSrc = SCNGeometrySource(data: colorData,
                                         semantic: .color,
                                         vectorCount: allColors.count,
                                         usesFloatComponents: true,
                                         componentsPerVector: 3,
                                         bytesPerComponent: MemoryLayout<Float>.stride,
                                         dataOffset: 0,
                                         dataStride: MemoryLayout<SCNVector3>.stride)

        let indexData = Data(bytes: allIndices, count: allIndices.count * MemoryLayout<Int32>.stride)
        let element = SCNGeometryElement(data: indexData,
                                         primitiveType: .triangles,
                                         primitiveCount: allIndices.count / 3,
                                         bytesPerIndex: MemoryLayout<Int32>.stride)

        let geo = SCNGeometry(sources: [vertexSrc, colorSrc], elements: [element])
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.transparency = 0.45
        geo.materials = [mat]
        return geo
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let meshAnchor = anchor as? ARMeshAnchor,
              let geo = createMeshSCNGeometry(from: meshAnchor.geometry) else { return }
        let meshNode = SCNNode(geometry: geo)
        self.meshActive = self.meshNodes.count > 0
        node.addChildNode(meshNode)
        meshNodes[meshAnchor.identifier] = meshNode
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let meshAnchor = anchor as? ARMeshAnchor,
              let existingNode = meshNodes[meshAnchor.identifier] else { return }
        updateMeshNode(existingNode, from: meshAnchor.geometry)
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let meshAnchor = anchor as? ARMeshAnchor else { return }
        meshNodes[meshAnchor.identifier]?.removeFromParentNode()
        meshNodes.removeValue(forKey: meshAnchor.identifier)
        self.meshActive = self.meshNodes.count > 0
    }


    // MARK: — Polygon Floor Mode —

    func startPolygonMode() {
        polygonVertices = []
        polygonClosed = false
        polygonFloorY = 0
        stage = .polygonFloor
        sessionMessage = stage.instruction
    }

    func closePolygon() {
        guard polygonVertices.count >= 3 else {
            sessionMessage = "Place at least 3 vertices before closing the shape."
            return
        }
        polygonClosed = true
        stage = .polygonHeight
        sessionMessage = stage.instruction
        computePolygonFloorY()
        updateLiveHeightFromDevice()
        refreshPolygonPreview()
    }

    private func addPolygonVertex(at position: SIMD3<Float>) {
        guard !polygonClosed else { return }
        let snapped = snapToNearestSurface(from: position)
        polygonVertices.append(snapped)
        if polygonVertices.count == 1 {
            polygonFloorY = snapped.y
        }
        sessionMessage = "\(polygonVertices.count) vertices placed. Tap to add more or close the shape."
        refreshPolygonPreview()
    }

    private func snapToNearestSurface(from position: SIMD3<Float>) -> SIMD3<Float> {
        guard let frame = sceneView?.session.currentFrame else { return position }
        var best = position
        var bestDist: Float = 0.25

        for anchor in frame.anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
            if stage == .polygonFloor && planeAnchor.alignment != .horizontal { continue }
            let t = planeAnchor.transform
            let center = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
            let normal = SIMD3<Float>(t.columns.1.x, t.columns.1.y, t.columns.1.z)
            let offset = position - center
            let planeDist = abs(simd_dot(offset, simd_normalize(normal)))
            if planeDist < bestDist {
                let projected = position - normal * simd_dot(offset, normal) / simd_length_squared(normal)
                let extent = planeAnchor.extent
                if simd_distance(projected, center) < max(extent.x, extent.z) {
                    bestDist = planeDist
                    best = SIMD3<Float>(projected.x, position.y, projected.z)
                }
            }
        }

        if bestDist > 0.15 {
            for anchor in frame.anchors {
                if let meshAnchor = anchor as? ARMeshAnchor {
                    let geo = meshAnchor.geometry; let vc = geo.vertices.count
                    guard vc > 0 else { continue }
                    let buf = geo.vertices.buffer.contents().assumingMemoryBound(to: (Float, Float, Float).self)
                    let t = meshAnchor.transform
                    for i in stride(from: 0, to: vc, by: max(1, vc / 200)) {
                        let v = buf[i]
                        let wp = SIMD3<Float>(t.columns.0.x * v.0 + t.columns.1.x * v.1 + t.columns.2.x * v.2 + t.columns.3.x,
                                              t.columns.0.y * v.0 + t.columns.1.y * v.1 + t.columns.2.y * v.2 + t.columns.3.y,
                                              t.columns.0.z * v.0 + t.columns.1.z * v.1 + t.columns.2.z * v.2 + t.columns.3.z)
                        let d = simd_distance(position, wp)
                        if d < bestDist { bestDist = d; best = wp }
                    }
                }
            }
        }
        return best
    }

    private func computePolygonFloorY() {
        guard !polygonVertices.isEmpty else { return }
        polygonFloorY = polygonVertices.map { $0.y }.reduce(0, +) / Float(polygonVertices.count)
    }

    private func lockPolygonHeight(worldY: Float, source: PointSource) {
        guard polygonClosed else { return }
        let height = worldY - polygonFloorY
        guard height >= 0.15 else {
            sessionMessage = "Raise the phone at least 6 inches above the floor."
            return
        }
        lockedHeight = height
        upperSource = source
        liveDimensions.y = height
        commitPolygonVolume(height: height)
    }

    private func polygonFloorArea() -> Float {
        guard polygonVertices.count >= 3 else { return 0 }
        var area: Float = 0
        let n = polygonVertices.count
        for i in 0..<n {
            let j = (i + 1) % n
            area += polygonVertices[i].x * polygonVertices[j].z
            area -= polygonVertices[j].x * polygonVertices[i].z
        }
        return abs(area) / 2
    }

    private func polygonVolumeCorners(height: Float) -> [ScanPointLabel: SIMD3<Float>]? {
        guard polygonVertices.count >= 3, polygonClosed else { return nil }
        var result: [ScanPointLabel: SIMD3<Float>] = [:]
        let floorLabels: [ScanPointLabel] = [.rearLeftFloor, .rearRightFloor, .frontRightFloor, .frontLeftFloor]
        let upperLabels: [ScanPointLabel] = [.rearLeftUpper, .rearRightUpper, .frontRightUpper, .frontLeftUpper]
        let up = SIMD3<Float>(0, height, 0)

        for i in 0..<min(4, polygonVertices.count) {
            result[floorLabels[i]] = polygonVertices[i]
            result[upperLabels[i]] = polygonVertices[i] + up
        }

        if result.count < 8 {
            let bounds = polygonBounds()
            let extras: [(Float, Float)] = [(bounds.maxX, bounds.maxZ), (bounds.maxX, bounds.minZ), (bounds.minX, bounds.maxZ), (bounds.minX, bounds.minZ)]
            for (label, (ex, ez)) in zip(floorLabels, extras) {
                if result[label] == nil {
                    result[label] = SIMD3<Float>(ex, polygonFloorY, ez)
                    if let idx = floorLabels.firstIndex(of: label) {
                        result[upperLabels[idx]] = SIMD3<Float>(ex, polygonFloorY + height, ez)
                    }
                }
            }
        }
        return result
    }

    private func polygonBounds() -> (minX: Float, maxX: Float, minZ: Float, maxZ: Float) {
        var minX = Float.greatestFiniteMagnitude; var maxX = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude; var maxZ = -Float.greatestFiniteMagnitude
        for v in polygonVertices { minX = min(minX, v.x); maxX = max(maxX, v.x); minZ = min(minZ, v.z); maxZ = max(maxZ, v.z) }
        return (minX, maxX, minZ, maxZ)
    }

    private func commitPolygonVolume(height: Float) {
        guard let corners = polygonVolumeCorners(height: height) else { return }
        let ordered = ScanPointLabel.allCases.compactMap { label -> ScanPoint? in
            guard let position = corners[label] else { return nil }
            let src = ScanPointLabel.floorLabels.contains(label) ? (isLiDARAvailable ? .lidarDepth : .existingPlaneGeometry) : upperSource
            return ScanPoint(label: label, position: CodableVector3(position), source: src)
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

    private func refreshPolygonPreview() {
        previewNode?.removeFromParentNode()
        previewNode = nil
        guideNode?.removeFromParentNode()
        guideNode = nil
        guard !polygonVertices.isEmpty else { return }

        let parent = SCNNode()
        parent.name = "polygon"
        let n = polygonVertices.count

        for i in 0..<n {
            let j = (i + 1) % n
            if polygonClosed || i < n - 1 {
                let edge = MarkerEntityFactory.createMeasurementLine(from: polygonVertices[i], to: polygonVertices[j])
                parent.addChildNode(edge)
            }
        }

        for v in polygonVertices {
            let marker = MarkerEntityFactory.createMarker(label: .rearLeftFloor, position: SCNVector3FromSIMD(v))
            parent.addChildNode(marker)
        }

        if polygonClosed, polygonVertices.count >= 3 {
            let area = polygonFloorArea()
            let areaSqFt = Double(area) * 10.764
            let centroid = SIMDHelpers.centroid(of: polygonVertices)
            let label = MarkerEntityFactory.createLabel(text: String(format: "%.1f sq ft", areaSqFt), at: SCNVector3FromSIMD(centroid))
            parent.addChildNode(label)
        }

        sceneView?.scene.rootNode.addChildNode(parent)
        previewNode = parent

        let bounds = polygonBounds()
        liveDimensions = SIMD3<Float>(bounds.maxX - bounds.minX, lockedHeight ?? max(liveDimensions.y, 0.15), bounds.maxZ - bounds.minZ)

        if polygonClosed {
            let camY = sceneView?.session.currentFrame?.camera.transform.columns.3.y ?? polygonFloorY
            let h = max(0.15, lockedHeight ?? (camY - polygonFloorY))
            let up = SIMD3<Float>(0, h, 0)
            for v in polygonVertices {
                let ve = MarkerEntityFactory.createMeasurementLine(from: v, to: v + up)
                parent.addChildNode(ve)
            }
            for i in 0..<n {
                let j = (i + 1) % n
                let ue = MarkerEntityFactory.createMeasurementLine(from: polygonVertices[i] + up, to: polygonVertices[j] + up)
                parent.addChildNode(ue)
            }
        }
    }


    // MARK: — ARSessionDelegate —

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let now = frame.timestamp
        DispatchQueue.main.async {
            self.trackingState = frame.camera.trackingState
            self.surfaceReady = self.planeCount > 0 || frame.sceneDepth != nil || frame.smoothedSceneDepth != nil

            if self.stage == .auto {
                // Process auto-room detection every 4th frame for performance
                self.sampledFrames += 1
                // Show LiDAR activity
                if self.meshNodes.count > 0 && self.sampledFrames == 5 {
                    self.sessionMessage = "LiDAR active — mesh on surfaces. Keep panning."
                }
                if self.sampledFrames % 2 == 0 {
                    // Use plane anchors for wall/floor detection
                    for anchor in frame.anchors {
                        if let planeAnchor = anchor as? ARPlaneAnchor {
                            if planeAnchor.alignment == .horizontal || planeAnchor.alignment == .vertical {
                                self.expandRoomFromPlane(planeAnchor)
                            }
                        }
                    }

                    // LiDAR: sample mesh vertices
                    if self.isLiDARAvailable {
                        for anchor in frame.anchors {
                            if let meshAnchor = anchor as? ARMeshAnchor {
                                self.sampleMeshVertices(from: meshAnchor)
                            }
                        }
                    }

                    self.autoRoomReady = self.roomMinBounds != nil && self.sampledFrames > 10
                    self.refreshAutoPreview()

                    if self.sampledFrames == 20 {
                        self.sessionMessage = "Room detected. Pan to expand. Tap Lock when ready."
                    }
                }
            } else             // Check surface at crosshair every 8th frame
            if self.sampledFrames % 8 == 0, let sv = self.sceneView, sv.bounds.width > 0, self.stage != .complete {
                let cp = CGPoint(x: sv.bounds.midX, y: sv.bounds.midY - 40)
                let orient = sv.window?.windowScene?.interfaceOrientation ?? .portrait
                let align: ARRaycastQuery.TargetAlignment = (self.stage == .height || self.stage == .polygonHeight) ? .any : .horizontal
                self.crosshairSurfaceFound = PointPlacementService.place(at: cp, in: frame, session: sv.session, viewportSize: sv.bounds.size, orientation: orient, alignment: align) != nil
            }

                        // Update crosshair surface detection
            self.updateCrosshair(from: frame)

            if self.stage == .polygonHeight, now - self.lastPreviewUpdate > 0.08 {
                self.lastPreviewUpdate = now
                let camY = frame.camera.transform.columns.3.y
                let h = max(0.15, camY - self.polygonFloorY)
                self.deviceHeightAboveFloor = max(0, camY - self.polygonFloorY)
                self.liveDimensions.y = h
                self.refreshPolygonPreview()
            } else if self.stage == .height, now - self.lastPreviewUpdate > 0.08 {
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
            if added > 0 {
                if self.stage == .auto {
                    self.sessionMessage = "Detecting walls and floor..."
                } else if self.stage == .floor {
                    self.sessionMessage = "Floor detected. Set the first corner."
                }
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
