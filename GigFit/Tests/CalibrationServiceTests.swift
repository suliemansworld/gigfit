import XCTest
@testable import GigFit

final class CalibrationServiceTests: XCTestCase {

    func testScaleFactor() {
        let pointA = SIMD3<Float>(0, 0, 0)
        let pointB = SIMD3<Float>(2, 0, 0) // 2m apart in ARKit space

        let cal = CalibrationService.calibrate(
            pointA: pointA, pointB: pointB,
            knownDistanceInches: 78.74, // 2 meters in inches
            labelA: .rearLeftFloor, labelB: .rearRightFloor
        )

        XCTAssertEqual(cal.scaleFactor, 1.0, accuracy: 0.01)
    }

    func testScaleFactorDouble() {
        let pointA = SIMD3<Float>(0, 0, 0)
        let pointB = SIMD3<Float>(1, 0, 0) // 1m apart but real distance is 2m

        let cal = CalibrationService.calibrate(
            pointA: pointA, pointB: pointB,
            knownDistanceInches: 78.74, // 2 meters
            labelA: .rearLeftFloor, labelB: .rearRightFloor
        )

        XCTAssertEqual(cal.scaleFactor, 2.0, accuracy: 0.01)
    }

    func testApplyCalibration() {
        let points: [ScanPointLabel: SIMD3<Float>] = [
            .rearLeftFloor:  SIMD3<Float>(0, 0, 0),
            .rearRightFloor: SIMD3<Float>(1, 0, 0),
        ]

        let cal = CalibrationService.Calibration(
            scaleFactor: 2.0,
            knownDistanceMeters: 2.0,
            pointALabel: .rearLeftFloor,
            pointBLabel: .rearRightFloor,
            measuredDistanceMeters: 1.0
        )

        let scaled = CalibrationService.applyCalibration(cal, to: points)
        XCTAssertEqual(scaled[.rearRightFloor]!.x, 2.0, accuracy: 0.01)
    }
}
