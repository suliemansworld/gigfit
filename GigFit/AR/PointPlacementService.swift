import Foundation
import ARKit
import simd

/// Produces real-world positions from detected planes or LiDAR depth.
enum PointPlacementService {

    private static let minimumPlacementDistanceMeters: Float = 0.08
    private static let maximumPlacementDistanceMeters: Float = 8

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
        guard let imagePoint = normalizedImagePoint(
            from: screenPoint,
            frame: frame,
            viewportSize: viewportSize,
            orientation: orientation
        ) else { return nil }

        // Prefer a real detected plane, then the visible LiDAR surface. An
        // infinite plane is only a last resort because its intersection can be
        // far away from the package or tabletop under the crosshair.
        if let planeResult = raycast(
            at: imagePoint,
            session: session,
            allowing: .existingPlaneGeometry,
            alignment: alignment,
            source: .existingPlaneGeometry,
            frame: frame
        ) {
            return planeResult
        }

        if let depthPosition = depthPosition(
            at: imagePoint,
            frame: frame
        ) {
            return result(position: depthPosition, source: .lidarDepth, anchor: nil, frame: frame)
        }

        let fallbackTargets: [(ARRaycastQuery.Target, PointSource)] = [
            (.estimatedPlane, .estimatedPlane),
            (.existingPlaneInfinite, .existingPlaneInfinite)
        ]
        for (target, source) in fallbackTargets {
            if let fallback = raycast(
                at: imagePoint,
                session: session,
                allowing: target,
                alignment: alignment,
                source: source,
                frame: frame
            ) {
                return fallback
            }
        }

        return nil
    }

    private static func raycast(
        at imagePoint: CGPoint,
        session: ARSession,
        allowing target: ARRaycastQuery.Target,
        alignment: ARRaycastQuery.TargetAlignment,
        source: PointSource,
        frame: ARFrame
    ) -> PlacementResult? {
        // ARFrame expects normalized captured-image coordinates, not UIKit
        // view coordinates. Passing screen points here creates an invalid ray.
        let query = frame.raycastQuery(from: imagePoint, allowing: target, alignment: alignment)
        guard let first = session.raycast(query).first else { return nil }

        let position = SIMD3<Float>(first.worldTransform.columns.3.x,
                                    first.worldTransform.columns.3.y,
                                    first.worldTransform.columns.3.z)
        let placement = result(position: position, source: source, anchor: first.anchor, frame: frame)
        guard placement.distanceMeters >= minimumPlacementDistanceMeters,
              placement.distanceMeters <= maximumPlacementDistanceMeters else { return nil }
        return placement
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
        at imagePoint: CGPoint,
        frame: ARFrame
    ) -> SIMD3<Float>? {
        guard let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth else { return nil }

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
        guard depth.isFinite,
              depth > minimumPlacementDistanceMeters,
              depth < maximumPlacementDistanceMeters else { return nil }

        let imageResolution = frame.camera.imageResolution
        let pixel = SIMD3<Float>(Float(imagePoint.x * imageResolution.width),
                                 Float(imagePoint.y * imageResolution.height),
                                 1)
        let ray = frame.camera.intrinsics.inverse * pixel
        let cameraPoint = SIMD4<Float>(ray.x * depth, -ray.y * depth, -depth, 1)
        let worldPoint = frame.camera.transform * cameraPoint
        return SIMD3<Float>(worldPoint.x, worldPoint.y, worldPoint.z)
    }

    private static func normalizedImagePoint(
        from screenPoint: CGPoint,
        frame: ARFrame,
        viewportSize: CGSize,
        orientation: UIInterfaceOrientation
    ) -> CGPoint? {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return nil }

        let normalizedViewPoint = CGPoint(
            x: screenPoint.x / viewportSize.width,
            y: screenPoint.y / viewportSize.height
        )
        let imagePoint = normalizedViewPoint.applying(
            frame.displayTransform(for: orientation, viewportSize: viewportSize).inverted()
        )
        guard imagePoint.x.isFinite,
              imagePoint.y.isFinite,
              (0...1).contains(imagePoint.x),
              (0...1).contains(imagePoint.y) else { return nil }
        return imagePoint
    }
}
