import Foundation
import ARKit
import simd

/// Handles hit-testing to place points on detected surfaces.
enum PointPlacementService {

    struct PlacementResult {
        let worldPosition: SIMD3<Float>
        let source: PointSource
        let anchor: ARAnchor?
        let distanceMeters: Float
    }

    /// Perform a hit-test at the given screen point.
    /// Prioritizes: existing plane geometry → infinite plane → estimated plane → fallback.
    static func place(
        at screenPoint: CGPoint,
        in frame: ARFrame,
        session: ARSession
    ) -> PlacementResult? {

        let hitTestResults = frame.hitTest(screenPoint, types: [.existingPlaneUsingGeometry,
                                                                .existingPlaneUsingExtent,
                                                                .estimatedHorizontalPlane,
                                                                .estimatedVerticalPlane,
                                                                .featurePoint])

        for result in hitTestResults {
            let pos = SIMD3<Float>(result.worldTransform.columns.3.x,
                                    result.worldTransform.columns.3.y,
                                    result.worldTransform.columns.3.z)
            let source: PointSource
            let anchor: ARAnchor?

            switch result.type {
            case .existingPlaneUsingGeometry:
                source = .existingPlaneGeometry
                anchor = result.anchor
            case .existingPlaneUsingExtent:
                source = .existingPlaneInfinite
                anchor = result.anchor
            default:
                source = .estimatedPlane
                anchor = nil
            }

            let camPos = SIMD3<Float>(frame.camera.transform.columns.3.x,
                                       frame.camera.transform.columns.3.y,
                                       frame.camera.transform.columns.3.z)
            let distance = simd_distance(pos, camPos)

            return PlacementResult(worldPosition: pos, source: source,
                                    anchor: anchor, distanceMeters: distance)
        }

        // Fallback: raycast using estimated plane detection
        if let query = session.currentFrame?.raycastQuery(from: screenPoint,
                                                           allowing: .estimatedPlane,
                                                           alignment: .any) {
            let raycastResults = session.raycast(query)
            if let first = raycastResults.first {
                let pos = SIMD3<Float>(first.worldTransform.columns.3.x,
                                        first.worldTransform.columns.3.y,
                                        first.worldTransform.columns.3.z)
                let camPos = SIMD3<Float>(frame.camera.transform.columns.3.x,
                                           frame.camera.transform.columns.3.y,
                                           frame.camera.transform.columns.3.z)
                return PlacementResult(worldPosition: pos, source: .estimatedPlane,
                                        anchor: first.anchor, distanceMeters: simd_distance(pos, camPos))
            }
        }

        // Last resort: raycast at 2m depth along camera ray
        let cameraTransform = frame.camera.transform
        let camPos = SIMD3<Float>(cameraTransform.columns.3.x,
                                   cameraTransform.columns.3.y,
                                   cameraTransform.columns.3.z)
        let forward = SIMD3<Float>(-cameraTransform.columns.2.x,
                                    -cameraTransform.columns.2.y,
                                    -cameraTransform.columns.2.z)
        let pos = camPos + forward * 2.0

        return PlacementResult(worldPosition: pos, source: .estimatedPlane,
                                anchor: nil, distanceMeters: 2.0)
    }
}
