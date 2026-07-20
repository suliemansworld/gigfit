import XCTest
@testable import GigFit

final class VolumeCalculatorTests: XCTestCase {

    // MARK: — Tetrahedron volume —

    func testTetrahedronVolume_UnitTetrahedron_ReturnsCorrectValue() {
        // A unit tetrahedron with vertices at origin and points along axes
        let a = SIMD3<Float>(0, 0, 0)
        let b = SIMD3<Float>(1, 0, 0)
        let c = SIMD3<Float>(0, 1, 0)
        let d = SIMD3<Float>(0, 0, 1)

        let vol = VolumeCalculator.tetrahedronVolume(a, b, c, d)
        // V = |(b-a)·((c-a)×(d-a))| / 6 = |(1,0,0)·((0,1,0)×(0,0,1))| / 6 = |(1,0,0)·(1,0,0)| / 6 = 1/6
        XCTAssertEqual(vol, 1.0 / 6.0, accuracy: 0.0001)
    }

    func testTetrahedronVolume_RegularTetrahedron_ReturnsPositive() {
        let edge: Float = 2.0
        let h: Float = sqrt(6) / 3 * edge
        let a = SIMD3<Float>(0, 0, 0)
        let b = SIMD3<Float>(edge, 0, 0)
        let c = SIMD3<Float>(edge / 2, sqrt(3) / 2 * edge, 0)
        let d = SIMD3<Float>(edge / 2, sqrt(3) / 6 * edge, h)

        let vol = VolumeCalculator.tetrahedronVolume(a, b, c, d)
        // V = edge³ / (6√2) for regular tetrahedron
        let expected = Double(edge * edge * edge) / (6.0 * sqrt(2))
        XCTAssertEqual(vol, expected, accuracy: 0.01)
    }

    // MARK: — 8-point hexahedron volume —

    func testComputeVolume_PerfectBox_ReturnsCorrectVolume() {
        // A perfect 2m × 1.5m × 1m box
        let w: Float = 2.0    // x (width)
        let h: Float = 1.0    // y (height)
        let d: Float = 1.5    // z (depth/length)

        var points: [ScanPointLabel: SIMD3<Float>] = [:]
        points[.rearLeftFloor]   = SIMD3<Float>(-w/2, 0,  d/2)
        points[.rearRightFloor]  = SIMD3<Float>( w/2, 0,  d/2)
        points[.frontRightFloor] = SIMD3<Float>( w/2, 0, -d/2)
        points[.frontLeftFloor]  = SIMD3<Float>(-w/2, 0, -d/2)
        points[.rearLeftUpper]   = SIMD3<Float>(-w/2, h,  d/2)
        points[.rearRightUpper]  = SIMD3<Float>( w/2, h,  d/2)
        points[.frontRightUpper] = SIMD3<Float>( w/2, h, -d/2)
        points[.frontLeftUpper]  = SIMD3<Float>(-w/2, h, -d/2)

        let result = VolumeCalculator.compute(points: points)
        XCTAssertNotNil(result)
        // Expected: 2.0 × 1.5 × 1.0 = 3.0 m³
        XCTAssertEqual(result!.rawCubicMeters, 3.0, accuracy: 0.01)
        XCTAssertFalse(result!.hasNegativeTetrahedra)
    }

    func testComputeVolume_SlopedTop_ReturnsPositiveVolume() {
        // A box where the front wall is lower than the rear (sloped ceiling)
        let w: Float = 2.0
        let hRear: Float = 1.5
        let hFront: Float = 1.0
        let d: Float = 1.5

        var points: [ScanPointLabel: SIMD3<Float>] = [:]
        points[.rearLeftFloor]   = SIMD3<Float>(-w/2, 0,       d/2)
        points[.rearRightFloor]  = SIMD3<Float>( w/2, 0,       d/2)
        points[.frontRightFloor] = SIMD3<Float>( w/2, 0,      -d/2)
        points[.frontLeftFloor]  = SIMD3<Float>(-w/2, 0,      -d/2)
        points[.rearLeftUpper]   = SIMD3<Float>(-w/2, hRear,   d/2)
        points[.rearRightUpper]  = SIMD3<Float>( w/2, hRear,   d/2)
        points[.frontRightUpper] = SIMD3<Float>( w/2, hFront, -d/2)
        points[.frontLeftUpper]  = SIMD3<Float>(-w/2, hFront, -d/2)

        let result = VolumeCalculator.compute(points: points)
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.rawCubicMeters, 0)
        // Volume should be ~avg height × width × depth = ~1.25 × 2.0 × 1.5 = ~3.75
        XCTAssertEqual(result!.rawCubicMeters, 3.75, accuracy: 0.05)
    }

    func testComputeVolume_InsetApplied_CorrectReduction() {
        let w: Float = 2.0; let h: Float = 1.0; let d: Float = 1.5

        var points: [ScanPointLabel: SIMD3<Float>] = [:]
        points[.rearLeftFloor]   = SIMD3<Float>(-w/2, 0,  d/2)
        points[.rearRightFloor]  = SIMD3<Float>( w/2, 0,  d/2)
        points[.frontRightFloor] = SIMD3<Float>( w/2, 0, -d/2)
        points[.frontLeftFloor]  = SIMD3<Float>(-w/2, 0, -d/2)
        points[.rearLeftUpper]   = SIMD3<Float>(-w/2, h,  d/2)
        points[.rearRightUpper]  = SIMD3<Float>( w/2, h,  d/2)
        points[.frontRightUpper] = SIMD3<Float>( w/2, h, -d/2)
        points[.frontLeftUpper]  = SIMD3<Float>(-w/2, h, -d/2)

        let noInset = VolumeCalculator.compute(points: points, insetPercent: 0)
        let withInset = VolumeCalculator.compute(points: points, insetPercent: 5.0)

        XCTAssertNotNil(noInset)
        XCTAssertNotNil(withInset)
        let expectedConservative = 3.0 * pow(0.95, 3)
        XCTAssertEqual(withInset!.conservativeCubicMeters, expectedConservative, accuracy: 0.01)
        XCTAssertEqual(withInset!.rawCubicMeters, noInset!.rawCubicMeters, accuracy: 0.01)
    }
}
