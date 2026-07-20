import XCTest
@testable import GigFit

final class SafetyInsetCalculatorTests: XCTestCase {

    func testInsetPercent_HighConfidence_Returns2Percent() {
        XCTAssertEqual(SafetyInsetCalculator.insetPercent(for: 100), 2.0)
        XCTAssertEqual(SafetyInsetCalculator.insetPercent(for: 80), 2.0)
    }

    func testInsetPercent_MediumConfidence_Returns4Percent() {
        XCTAssertEqual(SafetyInsetCalculator.insetPercent(for: 79), 4.0)
        XCTAssertEqual(SafetyInsetCalculator.insetPercent(for: 50), 4.0)
    }

    func testInsetPercent_LowConfidence_Returns5Percent() {
        XCTAssertEqual(SafetyInsetCalculator.insetPercent(for: 49), 5.0)
        XCTAssertEqual(SafetyInsetCalculator.insetPercent(for: 0), 5.0)
    }

    func testApplyInset_ReducesVolumeCorrectly() {
        let raw = 100.0 // m³
        let inset = SafetyInsetCalculator.applyInset(to: raw, insetPercent: 2.0)
        XCTAssertEqual(inset, 100.0 * pow(0.98, 3), accuracy: 0.0001)
    }

    func testApplyInset_NearZero() {
        let raw = 0.001
        let inset = SafetyInsetCalculator.applyInset(to: raw, insetPercent: 5.0)
        XCTAssertGreaterThan(inset, 0)
    }
}
