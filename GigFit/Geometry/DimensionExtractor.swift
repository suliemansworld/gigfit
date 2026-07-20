import Foundation
import simd

/// Extracts L×W×H dimensions from the placed 8-point hexahedron.
///
/// Dimensions are computed as average distances between opposing face centroids:
///   - Length: rear face centroid → front face centroid
///   - Width:  left face centroid → right face centroid
///   - Height: floor face centroid → upper face centroid
enum DimensionExtractor {

    static func extract(from points: [ScanPointLabel: SIMD3<Float>]) -> ScanDimensions? {
        guard points.count == 8 else { return nil }

        let floorPoints = ScanPointLabel.floorLabels.compactMap { points[$0] }
        let upperPoints = ScanPointLabel.upperLabels.compactMap { points[$0] }
        guard floorPoints.count == 4, upperPoints.count == 4 else { return nil }

        // Rear face centroid
        let rearCentroid = SIMDHelpers.centroid(of: [
            points[.rearLeftFloor]!, points[.rearRightFloor]!,
            points[.rearLeftUpper]!, points[.rearRightUpper]!
        ])

        // Front face centroid
        let frontCentroid = SIMDHelpers.centroid(of: [
            points[.frontLeftFloor]!, points[.frontRightFloor]!,
            points[.frontLeftUpper]!, points[.frontRightUpper]!
        ])

        // Left face centroid
        let leftCentroid = SIMDHelpers.centroid(of: [
            points[.rearLeftFloor]!, points[.frontLeftFloor]!,
            points[.rearLeftUpper]!, points[.frontLeftUpper]!
        ])

        // Right face centroid
        let rightCentroid = SIMDHelpers.centroid(of: [
            points[.rearRightFloor]!, points[.frontRightFloor]!,
            points[.rearRightUpper]!, points[.frontRightUpper]!
        ])

        // Floor centroid
        let floorCentroid = SIMDHelpers.centroid(of: floorPoints)
        let upperCentroid = SIMDHelpers.centroid(of: upperPoints)

        let lengthMeters = Double(simd_distance(rearCentroid, frontCentroid))
        let widthMeters  = Double(simd_distance(leftCentroid, rightCentroid))
        let heightMeters = Double(simd_distance(floorCentroid, upperCentroid))

        return ScanDimensions(
            lengthMeters: lengthMeters,
            widthMeters: widthMeters,
            heightMeters: heightMeters,
            rawVolumeCubicMeters: lengthMeters * widthMeters * heightMeters,
            conservativeVolumeCubicMeters: 0 // filled after confidence calculation
        )
    }
}
