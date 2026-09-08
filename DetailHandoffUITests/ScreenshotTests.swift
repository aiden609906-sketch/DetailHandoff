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

        let appliedCategory = app.descendants(matching: .any)["ui.dynamicType.accessibility5"]
        XCTAssertTrue(appliedCategory.waitForExistence(timeout: 20), "The requested accessibility text category must be applied to the app process.")
        let jobsList = app.collectionViews.firstMatch
        XCTAssertTrue(jobsList.waitForExistence(timeout: 8), "The Jobs list must expose its scrollable collection at accessibility text sizes.")
        let vehicle = app.staticTexts["Complete Fixture Sedan"]
        for _ in 0..<12 where !vehicle.isHittable {
            jobsList.swipeUp()
        }
        XCTAssertTrue(vehicle.isHittable, "The complete fixture must remain reachable at accessibility text sizes.")
        vehicle.tap()
        let report = app.buttons["Review report"]
        for _ in 0..<12 where !report.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(report.isHittable, "The primary workflow action must remain visible and reachable at accessibility text sizes.")
        let photoPairLabel = app.staticTexts["Inspect photo pairs"]
        XCTAssertTrue(photoPairLabel.waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.windows.firstMatch.frame.contains(photoPairLabel.frame),
            "Accessibility-sized workflow action text must wrap inside the visible window instead of clipping horizontally."
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "accessibility-text-workflow"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
