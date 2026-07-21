import Foundation
import simd

/// Heuristic confidence scoring for scan quality.
/// Starts at 100, subtracts penalties for various quality issues.
enum ConfidenceScoring {

    struct ConfidenceResult {
        let score: Int
        let level: ScanConfidence
        let factors: [PenaltyFactor]

        struct PenaltyFactor: Identifiable {
            let id = UUID()
            let name: String
            let penalty: Int
        }
    }

    static func assess(
        points: [ScanPointLabel: SIMD3<Float>],
        hasCalibration: Bool,
        pointSources: [ScanPointLabel: PointSource]
    ) -> ConfidenceResult {
        var score = 100
        var factors: [ConfidenceResult.PenaltyFactor] = []

        // No calibration
        if !hasCalibration {
            score -= 10
            factors.append(.init(name: "No calibration provided", penalty: -10))
        }

        // Estimated points (no detected plane)
        let estimatedCount = pointSources.values.filter { $0 == .estimatedPlane }.count
        if estimatedCount > 0 {
            let penalty = min(estimatedCount * 5, 25)
            score -= penalty
            factors.append(.init(name: "\(estimatedCount) point(s) on approximate surfaces", penalty: -penalty))
        }

        // Infinite plane points — better than estimated, worse than geometry
        let infiniteCount = pointSources.values.filter { $0 == .existingPlaneInfinite }.count
        if infiniteCount > 0 {
            let penalty = min(infiniteCount * 3, 12)
            score -= penalty
            factors.append(.init(name: "\(infiniteCount) point(s) on estimated flat surfaces", penalty: -penalty))
        }

        // Implausible dimensions
        let labels = ScanPointLabel.allCases
        let positions = labels.compactMap { points[$0] }
        if positions.count == 8 {
            let xs = positions.map { $0.x }
            let ys = positions.map { $0.y }
            let zs = positions.map { $0.z }
            let maxDim = max(xs.max()! - xs.min()!, ys.max()! - ys.min()!, zs.max()! - zs.min()!)
            let minDim = min(xs.max()! - xs.min()!, ys.max()! - ys.min()!, zs.max()! - zs.min()!)

            if maxDim > 20 {
                score -= 25
                factors.append(.init(name: "Implausibly large dimension detected", penalty: -25))
            } else if maxDim < 0.1 {
                score -= 25
                factors.append(.init(name: "Implausibly small dimension detected", penalty: -25))
            }

            if minDim > 0.01 && maxDim / minDim > 10 {
                score -= 15
                factors.append(.init(name: "Extreme aspect ratio detected", penalty: -15))
            }
        }

        // Check for self-intersections via negative tetrahedra
        if let volume = VolumeCalculator.compute(points: points),
           volume.hasNegativeTetrahedra {
            let negCount = volume.tetrahedronVolumes.filter { $0 < -0.0001 }.count
            let penalty = negCount * 10
            score -= penalty
            factors.append(.init(name: "\(negCount) tetrahedron(s) have negative volume — possible self-intersection", penalty: -penalty))
        }

        score = max(0, min(100, score))

        let level: ScanConfidence
        switch score {
        case 80...: level = .high
        case 50..<80: level = .medium
        default: level = .low
        }

        return ConfidenceResult(score: score, level: level, factors: factors)
    }
}
