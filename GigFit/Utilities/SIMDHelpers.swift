import Foundation
import simd

enum SIMDHelpers {
    /// Centroid of an array of 3D points
    static func centroid(of points: [SIMD3<Float>]) -> SIMD3<Float> {
        guard !points.isEmpty else { return .zero }
        return points.reduce(.zero, +) / Float(points.count)
    }

    /// Euclidean distance between two points
    static func distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        simd_distance(a, b)
    }

    /// Average distance between two sets of matching points
    static func averageDistance(from setA: [SIMD3<Float>], to setB: [SIMD3<Float>]) -> Float {
        guard setA.count == setB.count, !setA.isEmpty else { return 0 }
        let sum = zip(setA, setB).reduce(0.0) { $0 + simd_distance($1.0, $1.1) }
        return sum / Float(setA.count)
    }

    /// Unit vector from two points
    static func direction(from: SIMD3<Float>, to: SIMD3<Float>) -> SIMD3<Float> {
        simd_normalize(to - from)
    }

    /// Scale a vector to a target length
    static func scale(_ vector: SIMD3<Float>, to length: Float) -> SIMD3<Float> {
        let current = simd_length(vector)
        guard current > .ulpOfOne else { return .zero }
        return simd_normalize(vector) * length
    }
}
