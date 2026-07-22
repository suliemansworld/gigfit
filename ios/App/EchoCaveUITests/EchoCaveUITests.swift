import XCTest

@MainActor
final class EchoCaveUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    func testWelcomeAccessibilityAndBackgroundRecovery() throws {
        let enter = app.buttons["Enter Echo Cave"]
        XCTAssertTrue(enter.waitForExistence(timeout: 10), "The first launch action must be exposed to VoiceOver.")
        XCTAssertTrue(enter.isHittable, "The first launch action must be activatable.")
        XCTAssertTrue(app.staticTexts["Echo Cave"].exists)

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(enter.waitForExistence(timeout: 5))

        if #available(iOS 17.0, *) {
            try app.performAccessibilityAudit()
        }
    }
}
