import XCTest
@testable import GigFit

final class SafetyInsetCalculatorTests: XCTestCase {

    func testHighConfidenceInset() {
        XCTAssertEqual(SafetyInsetCalculator.insetPercent(for: 85), 2.0)
        XCTAssertEqual(SafetyInsetCalculator.insetPercent(for: 100), 2.0)
    }

    func testMediumConfidenceInset() {
        XCTAssertEqual(SafetyInsetCalculator.insetPercent(for: 60), 4.0)
        XCTAssertEqual(SafetyInsetCalculator.insetPercent(for: 79), 4.0)
    }

    func testLowConfidenceInset() {
        XCTAssertEqual(SafetyInsetCalculator.insetPercent(for: 30), 5.0)
        XCTAssertEqual(SafetyInsetCalculator.insetPercent(for: 0), 5.0)
    }

    func testInsetMath() {
        let raw: Double = 100.0
        let inset = SafetyInsetCalculator.applyInset(to: raw, insetPercent: 4.0)
        // 100 * (1 - 0.04)³ = 100 * 0.884736 = 88.47
        XCTAssertEqual(inset, 88.4736, accuracy: 0.01)
    }
}
