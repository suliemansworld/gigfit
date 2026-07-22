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

        // Native integration smoke: welcome audio now starts automatically. If
        // its gate is already open, this activation enters the intro; otherwise
        // it resumes audio and a later activation must enter. The browser suite
        // isolates click-only activation; physical VoiceOver listening remains
        // required.
        enter.tap()
        let skipIntro = app.buttons["Skip intro"]
        if !skipIntro.waitForExistence(timeout: 2) {
            Thread.sleep(forTimeInterval: 14)
            let enterAfterWelcome = app.buttons["Enter Echo Cave"]
            XCTAssertTrue(enterAfterWelcome.waitForExistence(timeout: 2))
            enterAfterWelcome.tap()
        }
        XCTAssertTrue(
            skipIntro.waitForExistence(timeout: 5),
            "The native welcome must open the intro after its recorded audio gate."
        )
    }
}
