import Foundation
import simd

/// One-distance calibration: user measures a known distance between two points.
/// Scale factor = knownDistance / |pointA − pointB|
/// Applies to all points to convert from ARKit world units to real meters.
enum CalibrationService {

    struct Calibration {
        let scaleFactor: Double
        let knownDistanceMeters: Double
        let pointALabel: ScanPointLabel
        let pointBLabel: ScanPointLabel
        let measuredDistanceMeters: Double
    }

    /// Compute scale factor from two placed points and a known distance
    static func calibrate(
        pointA: SIMD3<Float>,
        pointB: SIMD3<Float>,
        knownDistanceInches: Double,
        labelA: ScanPointLabel,
        labelB: ScanPointLabel
    ) -> Calibration {
        let measuredDistance = Double(simd_distance(pointA, pointB))
        let knownMeters = knownDistanceInches / 39.3701
        let scaleFactor: Double
        if measuredDistance > 0.0001 {
            scaleFactor = knownMeters / measuredDistance
        } else {
            scaleFactor = 1.0
        }

        return Calibration(
            scaleFactor: scaleFactor,
            knownDistanceMeters: knownMeters,
            pointALabel: labelA,
            pointBLabel: labelB,
            measuredDistanceMeters: measuredDistance
        )
    }

    /// Apply calibration scale to a set of points
    static func applyCalibration(
        _ calibration: Calibration,
        to points: [ScanPointLabel: SIMD3<Float>]
    ) -> [ScanPointLabel: SIMD3<Float>] {
        guard abs(calibration.scaleFactor - 1.0) > 0.0001 else { return points }
        var scaled: [ScanPointLabel: SIMD3<Float>] = [:]
        for (label, pos) in points {
            scaled[label] = SIMD3<Float>(
                Float(Double(pos.x) * calibration.scaleFactor),
                Float(Double(pos.y) * calibration.scaleFactor),
                Float(Double(pos.z) * calibration.scaleFactor)
            )
        }
        return scaled
    }
}
