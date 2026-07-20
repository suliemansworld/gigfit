import Foundation
import simd

/// Builds a right-handed coordinate system from the 8 placed scan points.
/// Origin: centroid of the 4 floor points.
/// X-axis: rear-left to rear-right direction (width).
/// Y-axis: floor centroid to upper centroid (height, pointing up).
/// Z-axis: rear wall to front wall (depth/length).
struct CoordinateSystemBuilder {

    struct CoordinateSystem {
        let origin: SIMD3<Float>
        let xAxis: SIMD3<Float>
        let yAxis: SIMD3<Float>
        let zAxis: SIMD3<Float>
        var transform: float4x4 {
            float4x4(columns: (
                SIMD4<Float>(xAxis.x, xAxis.y, xAxis.z, 0),
                SIMD4<Float>(yAxis.x, yAxis.y, yAxis.z, 0),
                SIMD4<Float>(zAxis.x, zAxis.y, zAxis.z, 0),
                SIMD4<Float>(origin.x, origin.y, origin.z, 1)
            ))
        }
    }

    static func build(from points: [ScanPointLabel: SIMD3<Float>]) -> CoordinateSystem? {
        guard points.count == 8 else { return nil }

        let floorPoints: [SIMD3<Float>] = [
            points[.rearLeftFloor]!, points[.rearRightFloor]!,
            points[.frontRightFloor]!, points[.frontLeftFloor]!
        ]

        let upperPoints: [SIMD3<Float>] = [
            points[.rearLeftUpper]!, points[.rearRightUpper]!,
            points[.frontRightUpper]!, points[.frontLeftUpper]!
        ]

        let floorCentroid = SIMDHelpers.centroid(of: floorPoints)
        let upperCentroid = SIMDHelpers.centroid(of: upperPoints)

        // Y = up (floor to upper centroid)
        let yDir = simd_normalize(upperCentroid - floorCentroid)

        // X = floor rear-left to rear-right
        let rearLeftFloor = points[.rearLeftFloor]!
        let rearRightFloor = points[.rearRightFloor]!
        var xDir = simd_normalize(rearRightFloor - rearLeftFloor)
        // Orthogonalize X against Y
        xDir = simd_normalize(xDir - yDir * simd_dot(xDir, yDir))

        // Z = cross(X, Y), pointing toward front
        let zDir = simd_cross(xDir, yDir)

        let origin = floorCentroid

        return CoordinateSystem(origin: origin, xAxis: xDir, yAxis: yDir, zAxis: zDir)
    }
}
