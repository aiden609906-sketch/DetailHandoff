import XCTest

@MainActor
final class WorkflowUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCleanLaunchCreatesSearchableJobAndOpensWorkflow() throws {
        launch(arguments: ["--ui-testing"])

        require(app.navigationBars["Set up your business"])
        capture("setup")
        app.textFields["Business name"].tap()
        app.textFields["Business name"].typeText("Fixture Detail")
        app.buttons["Save"].tap()

        require(app.navigationBars["Jobs"])
        app.buttons["New job"].tap()
        require(app.navigationBars["New job"])
        capture("new-job")
        app.textFields["Vehicle"].tap()
        app.textFields["Vehicle"].typeText("QA-17 Sedan")
        dismissKeyboard()
        let create = app.buttons["newJob.create"]
        scrollUntilHittable(create)
        create.tap()

        require(app.staticTexts["QA-17 Sedan"])
        capture("list")
        app.searchFields["Customer, vehicle, or plate"].tap()
        app.searchFields["Customer, vehicle, or plate"].typeText("QA-17")
        require(app.staticTexts["QA-17 Sedan"])
        app.staticTexts["QA-17 Sedan"].tap()
        require(app.navigationBars["QA-17 Sedan"])
        capture("workflow")
    }

    func testCompleteFixturePreviewsSealsAndCancelsRealShareSheet() throws {
        launch(arguments: ["--ui-testing", "--screenshot-fixture", "complete"])

        openCaptureScreen()
        openFixtureWorkflow(named: "Complete Fixture Sedan")
        openFindingsScreen()
        require(app.buttons["Review report"])
        app.buttons["Review report"].tap()
        require(app.navigationBars["Report"])
        capture("report")

        app.buttons["report.acknowledgment"].tap()
        require(app.navigationBars["Acknowledgment"])
        capture("acknowledgment")
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["report.previewDraft"].tap()
        require(app.navigationBars["Draft preview"])
        capture("draft-pdf")
        dismissPresentedSheet()

        app.buttons["report.seal"].tap()
        require(app.buttons["report.confirmSeal"])
        app.buttons["report.confirmSeal"].tap()
        let version = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "report.version.")).firstMatch
        XCTAssertTrue(version.waitForExistence(timeout: 12), "Sealing a valid fixture should create a stored version.")
        capture("sealed-version")

        let share = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "report.share.")).firstMatch
        require(share)
        share.tap()
        let sharePresentation = requireSharePresentation()
        capture("share-sheet")
        dismissSharePresentation(sharePresentation)
        requireDismissed(sharePresentation, message: "Cancelling share should dismiss the system activity presentation.")
        XCTAssertTrue(version.exists, "Cancelling share must leave the sealed report version available.")
        require(app.staticTexts["Sealed versions"])
    }

    func testCompleteFixtureAllowsHistoryAccessWhileCreatingRevision() throws {
        launch(arguments: ["--ui-testing", "--screenshot-fixture", "revision"])

        openFixtureWorkflow(named: "Revision Fixture SUV")
        app.buttons["workflow.sealedReport"].tap()
        require(app.navigationBars["Report"])
        let version = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "report.version.")).firstMatch
        require(version)
        app.buttons["report.createRevision"].tap()
        require(app.navigationBars["Report"])
        XCTAssertTrue(version.exists, "Existing report history must stay reachable while a revision is in progress.")
        capture("revision-history")
    }

    func testBackupExportCanBeCancelledAndTrashCanBeRestored() throws {
        launch(arguments: ["--ui-testing", "--screenshot-fixture", "trash"])

        app.tabBars.buttons["Settings"].tap()
        require(app.navigationBars["Settings"])
        capture("settings")
        app.staticTexts["Backup and restore"].tap()
        require(app.navigationBars["Backup and restore"])
        app.buttons["backup.export"].tap()
        let fileExporterPresentation = requireFileExporterPresentation()
        capture("backup")
        dismissFileExporterPresentation(fileExporterPresentation)
        requireDismissed(fileExporterPresentation, message: "Cancelling backup export should dismiss the document picker.")

        app.navigationBars.buttons.firstMatch.tap()
        app.staticTexts["Recently deleted"].tap()
        require(app.navigationBars["Recently deleted"])
        capture("trash")
        app.buttons["Restore"].tap()
        app.tabBars.buttons["Jobs"].tap()
        require(app.staticTexts["Trash Fixture Hatchback"])
    }

    func testStartupFailureOffersRetryIntoIsolatedStore() throws {
        launch(arguments: ["--ui-testing", "--startup-failure"])

        require(app.staticTexts["Local data store unavailable"])
        capture("startup-failure")
        app.buttons["Try Opening Again"].tap()
        require(app.navigationBars["Set up your business"])
    }

    private func launch(arguments: [String]) {
        app.launchArguments = arguments + ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment = ["XCUI_TESTING": "1"]
        app.launch()
    }

    private func openFixtureWorkflow(named vehicle: String) {
        require(app.navigationBars["Jobs"])
        capture("fixture-list")
        app.staticTexts[vehicle].tap()
        require(app.navigationBars[vehicle])
        capture("workflow")
    }

    private func openCaptureScreen() {
        require(app.staticTexts["Capture Fixture Coupe"])
        app.staticTexts["Capture Fixture Coupe"].tap()
        require(app.navigationBars["Capture Fixture Coupe"])
        let captureButton = app.buttons["workflow.openBeforeCapture"]
        scrollUntilHittable(captureButton)
        captureButton.tap()
        require(app.navigationBars["Before photos"])
        capture("capture")
        returnToJobs()
    }

    private func openFindingsScreen() {
        let findings = app.buttons["workflow.findings"]
        scrollUntilHittable(findings)
        findings.tap()
        require(app.navigationBars["Condition findings"])
        capture("findings")
        app.navigationBars.buttons.firstMatch.tap()
    }

    private func dismissKeyboard() {
        let done = app.keyboards.buttons["Done"]
        if done.waitForExistence(timeout: 1) {
            done.tap()
        } else {
            app.navigationBars["New job"].tap()
        }
    }

    private func scrollUntilHittable(_ element: XCUIElement, attempts: Int = 4, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<attempts where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Expected \(element) to be reachable after scrolling.", file: file, line: line)
    }

    private func returnToJobs() {
        for _ in 0..<3 where !app.navigationBars["Jobs"].exists {
            let back = app.navigationBars.buttons.firstMatch
            require(back)
            back.tap()
        }
        require(app.navigationBars["Jobs"])
    }

    private func requireSharePresentation() -> XCUIElement {
        let sheet = app.sheets.firstMatch
        if sheet.waitForExistence(timeout: 4) { return sheet }
        let popover = app.popovers.firstMatch
        if popover.waitForExistence(timeout: 4) { return popover }
        XCTFail("Share must present a system activity sheet on iPhone or a popover on iPad.")
        return app.otherElements.firstMatch
    }

    private func requireFileExporterPresentation() -> XCUIElement {
        let sheet = app.sheets.firstMatch
        if sheet.waitForExistence(timeout: 4) { return sheet }
        let popover = app.popovers.firstMatch
        if popover.waitForExistence(timeout: 4) { return popover }
        let documentPicker = app.navigationBars["Save to Files"]
        if documentPicker.waitForExistence(timeout: 4) { return documentPicker }
        XCTFail("Backup export must present the Files document picker on iPhone or iPad.")
        return app.otherElements.firstMatch
    }

    private func dismissSharePresentation(_ presentation: XCUIElement) {
        dismissSystemPresentation(presentation, controls: ["Close", "Cancel"])
    }

    private func dismissFileExporterPresentation(_ presentation: XCUIElement) {
        dismissSystemPresentation(presentation, controls: ["Cancel", "Close"])
    }

    private func dismissSystemPresentation(_ presentation: XCUIElement, controls: [String]) {
        for title in controls {
            let withinPresentation = presentation.buttons[title]
            if withinPresentation.waitForExistence(timeout: 2) {
                withinPresentation.tap()
                return
            }
            let applicationButton = app.buttons[title]
            if applicationButton.waitForExistence(timeout: 1) {
                applicationButton.tap()
                return
            }
        }
        XCTFail("No supported cancellation control was available for the system presentation.")
    }

    private func requireDismissed(_ presentation: XCUIElement, message: String) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: presentation
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed, message)
    }

    private func require(_ element: XCUIElement, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Expected \(element) to exist.", file: file, line: line)
    }

    private func capture(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
