import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {
    func testLargeAccessibilityTextKeepsWorkflowActionsVisible() throws {
        let app = XCUIApplication()
        let startedAt = ProcessInfo.processInfo.systemUptime
        var timeline: [String] = []
        var failureCheckpoints: [DiagnosticCheckpoint] = []
        app.launchArguments = [
            "--ui-testing", "--screenshot-fixture", "complete",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launchEnvironment = ["XCUI_TESTING": "1"]
        app.launch()
        record("app.launch returned", since: startedAt, in: &timeline)

        let appliedCategory = app.descendants(matching: .any)["ui.dynamicType.accessibility5"]
        let categoryReady = appliedCategory.waitForExistence(timeout: 20)
        record("dynamic-type marker ready=\(categoryReady)", since: startedAt, in: &timeline)
        if !categoryReady {
            failureCheckpoints.append(diagnosticCheckpoint(named: "dynamic-type-timeout", app: app))
            attachDiagnostics(failureCheckpoints, timeline: timeline)
        }
        XCTAssertTrue(categoryReady, "The requested accessibility text category must be applied to the app process.")
        let jobsList = app.descendants(matching: .any)
            .matching(identifier: "jobs.verticalScroll")
            .firstMatch
        let jobsReady = jobsList.waitForExistence(timeout: 12)
        record("jobs scroll ready=\(jobsReady)", since: startedAt, in: &timeline)
        guard jobsReady else {
            failureCheckpoints.append(diagnosticCheckpoint(named: "jobs-readiness-timeout", app: app))
            attachDiagnostics(failureCheckpoints, timeline: timeline)
            XCTFail("The Jobs list must expose its named vertical scroll container at accessibility text sizes.")
            return
        }
        let vehicleQuery = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Complete Fixture Sedan"))
        for _ in 0..<5 where !vehicleQuery.firstMatch.isHittable {
            jobsList.swipeUp()
        }
        let vehicle = vehicleQuery.firstMatch
        record("fixture row hittable=\(vehicle.isHittable)", since: startedAt, in: &timeline)
        guard vehicle.isHittable else {
            failureCheckpoints.append(diagnosticCheckpoint(named: "fixture-row-unreachable", app: app))
            attachDiagnostics(failureCheckpoints, timeline: timeline)
            XCTFail("The complete fixture must remain reachable at accessibility text sizes.")
            return
        }
        failureCheckpoints.append(diagnosticCheckpoint(named: "fixture-row-before-action", app: app))
        vehicle.tap()
        record("fixture row tap returned", since: startedAt, in: &timeline)
        waitForOneSecondDiagnosticCheckpoint(named: "fixture-navigation-post-action")
        record("fixture navigation +1s checkpoint", since: startedAt, in: &timeline)
        failureCheckpoints.append(diagnosticCheckpoint(named: "fixture-navigation-after-1s", app: app))
        let destinationBar = app.navigationBars["Complete Fixture Sedan"]
        let navigationReady = destinationBar.waitForExistence(timeout: 12)
        record("destination navigation ready=\(navigationReady)", since: startedAt, in: &timeline)
        guard navigationReady else {
            failureCheckpoints.append(diagnosticCheckpoint(named: "fixture-navigation-timeout", app: app))
            attachDiagnostics(failureCheckpoints, timeline: timeline)
            XCTFail("The complete fixture workflow must finish navigation at accessibility text sizes.")
            return
        }
        failureCheckpoints.append(diagnosticCheckpoint(named: "fixture-navigation-ready", app: app))
        let workflowScroll = app.descendants(matching: .any)
            .matching(identifier: "workflow.verticalScroll")
            .firstMatch
        let workflowReady = workflowScroll.waitForExistence(timeout: 12)
        record("workflow scroll ready=\(workflowReady)", since: startedAt, in: &timeline)
        guard workflowReady else {
            failureCheckpoints.append(diagnosticCheckpoint(named: "workflow-readiness-timeout", app: app))
            attachDiagnostics(failureCheckpoints, timeline: timeline)
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

    private struct DiagnosticCheckpoint {
        let name: String
        let screenshot: XCUIScreenshot
        let details: String
    }

    private func diagnosticCheckpoint(named name: String, app: XCUIApplication) -> DiagnosticCheckpoint {
        let screenshot = app.screenshot()
        let fixtureQuery = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Complete Fixture Sedan"))
        let details = [
            elementSummaries(fixtureQuery, heading: "fixture row candidates"),
            "jobs-scroll \(elementSummary(app.descendants(matching: .any).matching(identifier: "jobs.verticalScroll").firstMatch))",
            "workflow-scroll \(elementSummary(app.descendants(matching: .any).matching(identifier: "workflow.verticalScroll").firstMatch))",
            "destination-navigation \(elementSummary(app.navigationBars["Complete Fixture Sedan"]))",
            elementSummaries(app.navigationBars, heading: "navigation bars"),
            "app-window \(elementSummary(app.windows.firstMatch))",
            "app.debugDescription:\n\(app.debugDescription)"
        ].joined(separator: "\n")
        return DiagnosticCheckpoint(name: name, screenshot: screenshot, details: details)
    }

    private func record(
        _ event: String,
        since startedAt: TimeInterval,
        in timeline: inout [String]
    ) {
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        let entry = "t+\(String(format: "%.3f", elapsed))s \(event)"
        timeline.append(entry)
        print("UI_DIAGNOSTIC \(entry)")
    }

    private func attachDiagnostics(_ checkpoints: [DiagnosticCheckpoint], timeline: [String]) {
        let timelineAttachment = XCTAttachment(string: timeline.joined(separator: "\n"))
        timelineAttachment.name = "diagnostic-accessibility-navigation-timeline.txt"
        timelineAttachment.lifetime = .keepAlways
        add(timelineAttachment)

        for checkpoint in checkpoints {
            let screenshot = XCTAttachment(screenshot: checkpoint.screenshot)
            screenshot.name = "diagnostic-\(checkpoint.name)-screenshot"
            screenshot.lifetime = .keepAlways
            add(screenshot)

            let details = XCTAttachment(string: checkpoint.details)
            details.name = "diagnostic-\(checkpoint.name)-hierarchy.txt"
            details.lifetime = .keepAlways
            add(details)
        }
    }

    private func elementSummaries(_ query: XCUIElementQuery, heading: String) -> String {
        let elements = query.allElementsBoundByIndex
        guard !elements.isEmpty else { return "\(heading): none" }
        return (["\(heading): count=\(elements.count)"] + elements.enumerated().map { index, element in
            "[\(index)] \(elementSummary(element))"
        }).joined(separator: "\n")
    }

    private func elementSummary(_ element: XCUIElement) -> String {
        let value = element.value.map { quoted(String(describing: $0)) } ?? "nil"
        return "type=\(String(describing: element.elementType)) identifier=\(quoted(element.identifier)) label=\(quoted(element.label)) value=\(value) exists=\(element.exists) enabled=\(element.isEnabled) hittable=\(element.isHittable) frame=\(frameSummary(element.frame))"
    }

    private func waitForOneSecondDiagnosticCheckpoint(named name: String) {
        let expectation = XCTestExpectation(description: "Diagnostic checkpoint \(name)")
        expectation.isInverted = true
        _ = XCTWaiter.wait(for: [expectation], timeout: 1)
    }

    private func frameSummary(_ frame: CGRect) -> String {
        "(x: \(format(frame.origin.x)), y: \(format(frame.origin.y)), width: \(format(frame.size.width)), height: \(format(frame.size.height)))"
    }

    private func format(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }

    private func quoted(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\n", with: "\\n"))\""
    }
}
