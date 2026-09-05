import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {
    func testLargeAccessibilityTextKeepsWorkflowActionsVisible() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--screenshot-fixture", "complete",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launchEnvironment = ["XCUI_TESTING": "1"]
        app.launch()

        XCTAssertTrue(app.tabBars["ui.dynamicType.accessibility5"].waitForExistence(timeout: 8), "The requested accessibility text category must be applied to the app process.")
        let vehicle = app.staticTexts["Complete Fixture Sedan"]
        XCTAssertTrue(vehicle.waitForExistence(timeout: 8))
        vehicle.tap()
        let report = app.buttons["Review report"]
        XCTAssertTrue(report.waitForExistence(timeout: 8))
        for _ in 0..<4 where !report.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(report.isHittable, "The primary workflow action must remain visible and reachable at accessibility text sizes.")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "accessibility-text-workflow"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
