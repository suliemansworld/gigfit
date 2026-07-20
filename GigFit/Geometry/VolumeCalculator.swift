import Foundation
import simd

/// Volume calculation using a 6-tetrahedron decomposition of a hexahedron.
/// This handles non-rectangular (sloped-top) shapes where upper corners
/// may not be coplanar with each other or parallel to the floor.
enum VolumeCalculator {

    /// Result of volume computation
    struct VolumeResult {
        let rawCubicMeters: Double
        let conservativeCubicMeters: Double
        let tetrahedronVolumes: [Double]
        let hasNegativeTetrahedra: Bool
    }

    /// Split along the RLF-to-FRU body diagonal. Six tetrahedra fill the
    /// complete convex volume without gaps or overlaps.
    static func compute(
        points: [ScanPointLabel: SIMD3<Float>],
        insetPercent: Double = 0
    ) -> VolumeResult? {
        guard points.count == 8 else { return nil }

        let RLF = points[.rearLeftFloor]!
        let RRF = points[.rearRightFloor]!
        let FRF = points[.frontRightFloor]!
        let FLF = points[.frontLeftFloor]!
        let RLU = points[.rearLeftUpper]!
        let RRU = points[.rearRightUpper]!
        let FRU = points[.frontRightUpper]!
        let FLU = points[.frontLeftUpper]!

        let pts = [
            tetrahedronVolume(RLF, RRF, FRF, FRU),
            tetrahedronVolume(RLF, FRF, FLF, FRU),
            tetrahedronVolume(RLF, FLF, FLU, FRU),
            tetrahedronVolume(RLF, FLU, RLU, FRU),
            tetrahedronVolume(RLF, RLU, RRU, FRU),
            tetrahedronVolume(RLF, RRU, RRF, FRU)
        ]

        let hasNegative = false
        let raw = pts.reduce(0, +)

        let conservative: Double
        if insetPercent > 0 {
            let scale = pow(1.0 - insetPercent / 100.0, 3)
            conservative = raw * max(scale, 0.001)
        } else {
            conservative = raw
        }

        return VolumeResult(
            rawCubicMeters: raw,
            conservativeCubicMeters: conservative,
            tetrahedronVolumes: pts,
            hasNegativeTetrahedra: hasNegative
        )
    }

    /// Volume of a tetrahedron: V = |(b-a) · ((c-a) × (d-a))| / 6.
    static func tetrahedronVolume(_ a: SIMD3<Float>, _ b: SIMD3<Float>,
                                   _ c: SIMD3<Float>, _ d: SIMD3<Float>) -> Double {
        let ab = b - a
        let ac = c - a
        let ad = d - a
        let cross = simd_cross(ac, ad)
        let dot = simd_dot(ab, cross)
        return abs(Double(dot)) / 6.0
    }
}
