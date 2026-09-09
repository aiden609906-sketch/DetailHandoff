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
        guard jobsList.waitForExistence(timeout: 12) else {
            XCTFail("The Jobs list must expose its named vertical scroll container at accessibility text sizes.")
            return
        }
        let vehicleQuery = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Complete Fixture Sedan"))
        for _ in 0..<5 where !vehicleQuery.firstMatch.isHittable {
            jobsList.swipeUp()
        }
        let vehicle = vehicleQuery.firstMatch
        guard vehicle.isHittable else {
            XCTFail("The complete fixture must remain reachable at accessibility text sizes.")
            return
        }
        vehicle.tap()
        guard app.navigationBars["Complete Fixture Sedan"].waitForExistence(timeout: 12) else {
            XCTFail("The complete fixture workflow must finish navigation at accessibility text sizes.")
            return
        }
        let workflowScroll = app.descendants(matching: .any)
            .matching(identifier: "workflow.verticalScroll")
            .firstMatch
        guard workflowScroll.waitForExistence(timeout: 12) else {
            XCTFail("The workflow must expose its named vertical scroll container at accessibility text sizes.")
            return
        }
        let reportQuery = app.descendants(matching: .any)
            .matching(identifier: "workflow.report")
        for _ in 0..<5 where !reportQuery.firstMatch.isHittable {
            workflowScroll.swipeUp()
        }
        let report = reportQuery.firstMatch
        XCTAssertTrue(report.isHittable, "The primary workflow action must remain visible and reachable at accessibility text sizes.")
        let photoPairLabel = app.staticTexts["Inspect photo pairs"]
        XCTAssertTrue(photoPairLabel.waitForExistence(timeout: 8))
        let windowFrame = app.windows.firstMatch.frame
        let labelFrame = photoPairLabel.frame
        XCTAssertGreaterThanOrEqual(labelFrame.minX, windowFrame.minX, "Accessibility-sized workflow action text must not clip past the leading edge.")
        XCTAssertLessThanOrEqual(labelFrame.maxX, windowFrame.maxX, "Accessibility-sized workflow action text must not clip past the trailing edge.")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "accessibility-text-workflow"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
