import XCTest

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
        app.buttons["Create job"].tap()

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

        openFixtureWorkflow(named: "Complete Fixture Sedan")
        require(app.buttons["Review report"])
        app.buttons["Review report"].tap()
        require(app.navigationBars["Report"])
        capture("report")

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
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 8), "Share must present the system activity sheet.")
        capture("share-sheet")
        dismissPresentedSheet()
        XCTAssertFalse(app.sheets.firstMatch.exists, "Cancelling share should dismiss the real system activity sheet.")
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
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 8), "Backup export must open the system save panel.")
        capture("backup")
        dismissPresentedSheet()

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
        app.launchArguments = arguments
        app.launchEnvironment = ["XCUI_TESTING": "1"]
        app.launch()
    }

    private func openFixtureWorkflow(named vehicle: String) {
        require(app.navigationBars["Jobs"])
        capture("fixture-list")
        app.staticTexts[vehicle].tap()
        require(app.navigationBars[vehicle])
        capture("capture")
    }

    private func dismissPresentedSheet() {
        let close = app.buttons["Close"]
        if close.waitForExistence(timeout: 2) {
            close.tap()
            return
        }
        let done = app.buttons["Done"]
        if done.waitForExistence(timeout: 2) {
            done.tap()
            return
        }
        let cancel = app.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 2) {
            cancel.tap()
            return
        }
        XCTFail("No dismissal control was available for the presented system sheet.")
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
