import Foundation
import ARKit
import simd

/// Produces real-world positions from detected planes or LiDAR depth.
enum PointPlacementService {

    struct PlacementResult {
        let worldPosition: SIMD3<Float>
        let source: PointSource
        let anchor: ARAnchor?
        let distanceMeters: Float
    }

    static func place(
        at screenPoint: CGPoint,
        in frame: ARFrame,
        session: ARSession,
        viewportSize: CGSize,
        orientation: UIInterfaceOrientation,
        alignment: ARRaycastQuery.TargetAlignment
    ) -> PlacementResult? {
        let targets: [(ARRaycastQuery.Target, PointSource)] = [
            (.existingPlaneGeometry, .existingPlaneGeometry),
            (.existingPlaneInfinite, .existingPlaneInfinite)
        ]

        for (target, source) in targets {
            if let result = raycast(
                at: screenPoint,
                session: session,
                allowing: target,
                alignment: alignment,
                source: source,
                frame: frame
            ) {
                return result
            }
        }

        if let depthPosition = depthPosition(
            at: screenPoint,
            frame: frame,
            viewportSize: viewportSize,
            orientation: orientation
        ) {
            return result(position: depthPosition, source: .lidarDepth, anchor: nil, frame: frame)
        }

        return raycast(
            at: screenPoint,
            session: session,
            allowing: .estimatedPlane,
            alignment: alignment,
            source: .estimatedPlane,
            frame: frame
        )
    }

    private static func raycast(
        at point: CGPoint,
        session: ARSession,
        allowing target: ARRaycastQuery.Target,
        alignment: ARRaycastQuery.TargetAlignment,
        source: PointSource,
        frame: ARFrame
    ) -> PlacementResult? {
        let query = frame.raycastQuery(from: point, allowing: target, alignment: alignment)
        guard let first = session.raycast(query).first else { return nil }

        let position = SIMD3<Float>(first.worldTransform.columns.3.x,
                                    first.worldTransform.columns.3.y,
                                    first.worldTransform.columns.3.z)
        return result(position: position, source: source, anchor: first.anchor, frame: frame)
    }

    private static func result(
        position: SIMD3<Float>,
        source: PointSource,
        anchor: ARAnchor?,
        frame: ARFrame
    ) -> PlacementResult {
        let cameraPosition = SIMD3<Float>(frame.camera.transform.columns.3.x,
                                          frame.camera.transform.columns.3.y,
                                          frame.camera.transform.columns.3.z)
        return PlacementResult(worldPosition: position,
                               source: source,
                               anchor: anchor,
                               distanceMeters: simd_distance(position, cameraPosition))
    }

    private static func depthPosition(
        at point: CGPoint,
        frame: ARFrame,
        viewportSize: CGSize,
        orientation: UIInterfaceOrientation
    ) -> SIMD3<Float>? {
        guard viewportSize.width > 0,
              viewportSize.height > 0,
              let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth else { return nil }

        let viewPoint = CGPoint(x: point.x / viewportSize.width,
                                y: point.y / viewportSize.height)
        let imagePoint = viewPoint.applying(
            frame.displayTransform(for: orientation, viewportSize: viewportSize).inverted()
        )
        guard (0...1).contains(imagePoint.x), (0...1).contains(imagePoint.y) else { return nil }

        let depthMap = depthData.depthMap
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)
        let depthX = min(depthWidth - 1, max(0, Int(imagePoint.x * CGFloat(depthWidth))))
        let depthY = min(depthHeight - 1, max(0, Int(imagePoint.y * CGFloat(depthHeight))))
        let row = baseAddress.advanced(by: depthY * rowBytes).assumingMemoryBound(to: Float32.self)
        let depth = row[depthX]
        guard depth.isFinite, depth > 0.08, depth < 8 else { return nil }

        let imageResolution = frame.camera.imageResolution
        let pixel = SIMD3<Float>(Float(imagePoint.x * imageResolution.width),
                                 Float(imagePoint.y * imageResolution.height),
                                 1)
        let ray = frame.camera.intrinsics.inverse * pixel
        let cameraPoint = SIMD4<Float>(ray.x * depth, -ray.y * depth, -depth, 1)
        let worldPoint = frame.camera.transform * cameraPoint
        return SIMD3<Float>(worldPoint.x, worldPoint.y, worldPoint.z)
    }
}
