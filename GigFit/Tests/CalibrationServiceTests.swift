import XCTest
@testable import GigFit

final class CalibrationServiceTests: XCTestCase {

    func testCalibration_ExactValue_ScaleFactorOne() {
        let pointA = SIMD3<Float>(0, 0, 0)
        let pointB = SIMD3<Float>(1, 0, 0) // 1 meter apart

        let cal = CalibrationService.calibrate(
            pointA: pointA, pointB: pointB,
            knownDistanceInches: 39.3701, // exactly 1 meter
            labelA: .rearLeftFloor, labelB: .rearRightFloor
        )

        XCTAssertEqual(cal.scaleFactor, 1.0, accuracy: 0.001)
    }

    func testCalibration_ARKitUnderestimates_ScaleFactorGreaterThanOne() {
        // ARKit says the distance is 0.8m, but the real distance is 1.0m
        let pointA = SIMD3<Float>(0, 0, 0)
        let pointB = SIMD3<Float>(0.8, 0, 0) // ARKit says 0.8m

        let cal = CalibrationService.calibrate(
            pointA: pointA, pointB: pointB,
            knownDistanceInches: 39.3701, // real = 1.0m
            labelA: .rearLeftFloor, labelB: .rearRightFloor
        )

        // Scale factor should be 1.0/0.8 = 1.25
        XCTAssertEqual(cal.scaleFactor, 1.25, accuracy: 0.001)
    }

    func testCalibration_ApplyScalesAllPoints() {
        let pointA = SIMD3<Float>(0, 0, 0)
        let pointB = SIMD3<Float>(0.5, 0, 0) // ARKit says 0.5m, real is 1.0m

        let cal = CalibrationService.calibrate(
            pointA: pointA, pointB: pointB,
            knownDistanceInches: 39.3701, // 1.0m
            labelA: .rearLeftFloor, labelB: .rearRightFloor
        )

        var points: [ScanPointLabel: SIMD3<Float>] = [
            .rearLeftFloor: SIMD3<Float>(0, 0, 0),
            .rearRightFloor: SIMD3<Float>(0.5, 0, 0),
            .frontRightFloor: SIMD3<Float>(0.5, 0, 1.0),
            .frontLeftFloor: SIMD3<Float>(0, 0, 1.0),
            .rearLeftUpper: SIMD3<Float>(0, 1.0, 0),
            .rearRightUpper: SIMD3<Float>(0.5, 1.0, 0),
            .frontRightUpper: SIMD3<Float>(0.5, 1.0, 1.0),
            .frontLeftUpper: SIMD3<Float>(0, 1.0, 1.0),
        ]

        let scaled = CalibrationService.applyCalibration(cal, to: points)

        // Scale factor should be 2.0 — everything doubles
        XCTAssertEqual(scaled[.rearRightFloor]!.x, 1.0, accuracy: 0.001)
        XCTAssertEqual(scaled[.frontRightUpper]!.z, 2.0, accuracy: 0.001)
        XCTAssertEqual(scaled[.rearLeftUpper]!.y, 2.0, accuracy: 0.001)
    }

    func testCalibration_NearZeroDistance_ReturnsScaleFactorOne() {
        let pointA = SIMD3<Float>(0, 0, 0)
        let pointB = SIMD3<Float>(0, 0, 0)

        let cal = CalibrationService.calibrate(
            pointA: pointA, pointB: pointB,
            knownDistanceInches: 52,
            labelA: .rearLeftFloor, labelB: .rearRightFloor
        )

        XCTAssertEqual(cal.scaleFactor, 1.0, accuracy: 0.001)
    }
}
