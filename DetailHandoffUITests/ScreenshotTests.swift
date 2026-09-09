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
        let jobsList = app.descendants(matching: .any)
            .matching(identifier: "jobs.verticalScroll")
            .firstMatch
        XCTAssertTrue(jobsList.waitForExistence(timeout: 8), "The Jobs list must expose its named vertical scroll container at accessibility text sizes.")
        let vehicleQuery = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Complete Fixture Sedan"))
        for _ in 0..<12 where !vehicleQuery.firstMatch.isHittable {
            jobsList.swipeUp()
        }
        let vehicle = vehicleQuery.firstMatch
        XCTAssertTrue(vehicle.isHittable, "The complete fixture must remain reachable at accessibility text sizes.")
        vehicle.tap()
        let workflowScroll = app.descendants(matching: .any)
            .matching(identifier: "workflow.verticalScroll")
            .firstMatch
        XCTAssertTrue(workflowScroll.waitForExistence(timeout: 8), "The workflow must expose its named vertical scroll container at accessibility text sizes.")
        let reportQuery = app.buttons.matching(NSPredicate(format: "label == %@", "Review report"))
        for _ in 0..<12 where !reportQuery.firstMatch.isHittable {
            workflowScroll.swipeUp()
        }
        let report = reportQuery.firstMatch
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
