import XCTest

final class ScreenshotTests: XCTestCase {
    func testLargeAccessibilityTextKeepsWorkflowActionsVisible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--screenshot-fixture", "complete"]
        app.launchEnvironment = [
            "XCUI_TESTING": "1",
            "UIPreferredContentSizeCategoryName": "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let vehicle = app.staticTexts["Complete Fixture Sedan"]
        XCTAssertTrue(vehicle.waitForExistence(timeout: 8))
        vehicle.tap()
        let report = app.buttons["Review report"]
        XCTAssertTrue(report.waitForExistence(timeout: 8))
        XCTAssertTrue(report.isHittable, "The primary workflow action must remain visible and reachable at accessibility text sizes.")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "accessibility-text-workflow"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
