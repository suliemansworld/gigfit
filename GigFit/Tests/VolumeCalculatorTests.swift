import XCTest
@testable import GigFit

final class VolumeCalculatorTests: XCTestCase {

    func testUnitCube() {
        // 1m × 1m × 1m cube
        let pts: [ScanPointLabel: SIMD3<Float>] = [
            .rearLeftFloor:   SIMD3<Float>(0, 0, 0),
            .rearRightFloor:  SIMD3<Float>(1, 0, 0),
            .frontRightFloor: SIMD3<Float>(1, 0, 1),
            .frontLeftFloor:  SIMD3<Float>(0, 0, 1),
            .rearLeftUpper:   SIMD3<Float>(0, 1, 0),
            .rearRightUpper:  SIMD3<Float>(1, 1, 0),
            .frontRightUpper: SIMD3<Float>(1, 1, 1),
            .frontLeftUpper:  SIMD3<Float>(0, 1, 1),
        ]

        let result = VolumeCalculator.compute(points: pts)!
        XCTAssertEqual(result.rawCubicMeters, 1.0, accuracy: 0.01)
        XCTAssertFalse(result.hasNegativeTetrahedra)
    }

    func testLargerBox() {
        // 2m × 3m × 4m box
        let L: Float = 4, W: Float = 2, H: Float = 3
        let pts: [ScanPointLabel: SIMD3<Float>] = [
            .rearLeftFloor:   SIMD3<Float>(0, 0, 0),
            .rearRightFloor:  SIMD3<Float>(W, 0, 0),
            .frontRightFloor: SIMD3<Float>(W, 0, L),
            .frontLeftFloor:  SIMD3<Float>(0, 0, L),
            .rearLeftUpper:   SIMD3<Float>(0, H, 0),
            .rearRightUpper:  SIMD3<Float>(W, H, 0),
            .frontRightUpper: SIMD3<Float>(W, H, L),
            .frontLeftUpper:  SIMD3<Float>(0, H, L),
        ]

        let result = VolumeCalculator.compute(points: pts)!
        let expected = Double(L * W * H) // 24 m³
        XCTAssertEqual(result.rawCubicMeters, expected, accuracy: 0.1)
    }

    func testSlopedTop() {
        // Box with sloped top (front upper higher than rear upper)
        let pts: [ScanPointLabel: SIMD3<Float>] = [
            .rearLeftFloor:   SIMD3<Float>(0, 0, 0),
            .rearRightFloor:  SIMD3<Float>(1, 0, 0),
            .frontRightFloor: SIMD3<Float>(1, 0, 1),
            .frontLeftFloor:  SIMD3<Float>(0, 0, 1),
            .rearLeftUpper:   SIMD3<Float>(0, 1, 0),
            .rearRightUpper:  SIMD3<Float>(1, 1, 0),
            .frontRightUpper: SIMD3<Float>(1, 1.5, 1),
            .frontLeftUpper:  SIMD3<Float>(0, 1.5, 1),
        ]

        let result = VolumeCalculator.compute(points: pts)!
        // Volume should be between 1.0 and 1.5 cubic meters
        XCTAssertGreaterThan(result.rawCubicMeters, 0.9)
        XCTAssertLessThan(result.rawCubicMeters, 1.7)
    }

    func testTetrahedronVolume() {
        let a = SIMD3<Float>(0, 0, 0)
        let b = SIMD3<Float>(1, 0, 0)
        let c = SIMD3<Float>(0, 1, 0)
        let d = SIMD3<Float>(0, 0, 1)

        let vol = VolumeCalculator.tetrahedronVolume(a, b, c, d)
        // Volume of this tetrahedron = 1/6
        XCTAssertEqual(vol, 1.0/6.0, accuracy: 0.001)
    }

    func testInsetVolume() {
        let pts: [ScanPointLabel: SIMD3<Float>] = [
            .rearLeftFloor:   SIMD3<Float>(0, 0, 0),
            .rearRightFloor:  SIMD3<Float>(1, 0, 0),
            .frontRightFloor: SIMD3<Float>(1, 0, 1),
            .frontLeftFloor:  SIMD3<Float>(0, 0, 1),
            .rearLeftUpper:   SIMD3<Float>(0, 1, 0),
            .rearRightUpper:  SIMD3<Float>(1, 1, 0),
            .frontRightUpper: SIMD3<Float>(1, 1, 1),
            .frontLeftUpper:  SIMD3<Float>(0, 1, 1),
        ]

        let raw = VolumeCalculator.compute(points: pts, insetPercent: 0)!
        let inset = VolumeCalculator.compute(points: pts, insetPercent: 10)!

        // 10% inset on each dimension → (0.9)³ = 0.729
        XCTAssertEqual(inset.conservativeVolumeCubicMeters,
                       raw.rawCubicMeters * 0.729, accuracy: 0.01)
    }
}
