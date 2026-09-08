import XCTest

@MainActor
final class WorkflowUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // Catches parent onAppear reloading both edited and newly inserted templates after child Back.
    func testNestedTemplateEditsSurviveBackSaveAndReopen() throws {
        launch(arguments: ["--ui-testing", "--screenshot-fixture", "trash"])
        app.buttons["Settings"].firstMatch.tap()
        require(app.navigationBars["Settings"])
        app.staticTexts["Services and capture templates"].tap()
        require(app.navigationBars["Services and templates"])
        app.staticTexts["Standard Detail"].firstMatch.tap()
        require(app.navigationBars["Capture template"])
        replaceText(in: app.textFields["Template name"], with: "Revised Standard")
        replaceText(in: app.textFields["Position name"].firstMatch, with: "Front revised")
        app.navigationBars.buttons.firstMatch.tap()
        require(app.staticTexts["Revised Standard"].firstMatch)
        scrollUntilHittable(app.buttons["Add template"])
        app.buttons["Add template"].tap()
        scrollUntilHittable(app.staticTexts["Untitled template"].firstMatch)
        app.staticTexts["Untitled template"].firstMatch.tap()
        replaceText(in: app.textFields["Template name"], with: "Express Walkaround")
        app.navigationBars.buttons.firstMatch.tap()
        require(app.staticTexts["Express Walkaround"].firstMatch)
        app.navigationBars.buttons["Save"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        require(app.navigationBars["Settings"])
        app.staticTexts["Services and capture templates"].tap()
        scrollUntilHittable(app.staticTexts["Revised Standard"].firstMatch)
        app.staticTexts["Revised Standard"].firstMatch.tap()
        XCTAssertEqual(app.textFields["Template name"].value as? String, "Revised Standard")
        XCTAssertEqual(app.textFields["Position name"].firstMatch.value as? String, "Front revised")
        app.navigationBars.buttons.firstMatch.tap()
        scrollUntilHittable(app.staticTexts["Express Walkaround"].firstMatch)
        app.staticTexts["Express Walkaround"].firstMatch.tap()
        XCTAssertEqual(app.textFields["Template name"].value as? String, "Express Walkaround")
    }

    // Complete evidence must remain editable in review and revision; edits must block stale resealing.
    func testReviewAndRevisionExposePhotoCorrectionAndRequireNewAcknowledgment() throws {
        for revision in [false, true] {
            let vehicle = revision ? "Revision Fixture SUV" : "Complete Fixture Sedan"
            launch(arguments: ["--ui-testing", "--screenshot-fixture", revision ? "revision" : "complete"])
            openFixtureWorkflow(named: vehicle)
            if revision {
                app.buttons["workflow.sealedReport"].tap()
                require(reportVersion())
                app.buttons["report.createRevision"].tap()
                app.navigationBars.buttons.firstMatch.tap()
            }
            let afterRoute = app.buttons["workflow.editAfterCapture"]
            scrollUntilHittable(afterRoute)
            afterRoute.tap()
            require(app.navigationBars["After photos"])
            let afterRetake = app.buttons["capture.camera.front"]
            scrollUntilHittable(afterRetake)
            XCTAssertTrue(afterRetake.isEnabled)
            app.navigationBars.buttons.firstMatch.tap()
            let beforeRoute = app.buttons["workflow.editBeforeCapture"]
            scrollUntilHittable(beforeRoute)
            beforeRoute.tap()
            require(app.navigationBars["Before photos"])
            XCTAssertTrue(app.buttons["capture.camera.front"].isEnabled)
            let remove = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "capture.remove.rear.")).firstMatch
            scrollUntilHittable(remove)
            XCTAssertEqual(app.staticTexts["capture.count.rear"].label, "1 photo")
            remove.tap()
            XCTAssertEqual(app.staticTexts["capture.count.rear"].label, "0 photos")
            let skip = app.buttons["capture.skip.rear"]
            scrollUntilHittable(skip)
            skip.tap()
            let prompt = app.alerts["Skip this view"]
            require(prompt)
            prompt.textFields.firstMatch.typeText("Rechecked before handoff")
            prompt.buttons["Save"].tap()
            require(app.staticTexts["Skipped: Rechecked before handoff"])
            capture(revision ? "revision-before-correction" : "review-before-correction")
            app.navigationBars.buttons.firstMatch.tap()
            let review = app.buttons["Review report"]
            scrollUntilHittable(review)
            review.tap()
            app.buttons["report.seal"].tap()
            require(app.buttons["report.confirmSeal"])
            app.buttons["report.confirmSeal"].tap()
            require(app.alerts["Report issue"])
            app.alerts.buttons["Open acknowledgment"].tap()
            require(app.navigationBars["Acknowledgment"])
            let stale = app.staticTexts["acknowledgment.status"]
            scrollUntilHittable(stale)
            XCTAssertTrue(stale.label.contains("changed"))
            tapReachable(app.buttons["acknowledgment.replace"])
            let unavailable = app.buttons["Customer unavailable"]
            scrollUntilHittable(unavailable)
            unavailable.tap()
            app.alerts.textFields.firstMatch.typeText("Customer unavailable for correction")
            app.alerts.buttons["Record"].tap()
            app.navigationBars.buttons.firstMatch.tap()
            require(app.navigationBars["Report"])
            app.buttons["report.seal"].tap()
            require(app.buttons["report.confirmSeal"])
            app.buttons["report.confirmSeal"].tap()
            require(reportVersion())
            let expectedVersion = revision ? "Version 2" : "Version 1"
            require(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", expectedVersion)).firstMatch)
            if revision {
                let originalPreview = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "report.preview.")).element(boundBy: 1)
                scrollUntilHittable(originalPreview)
                originalPreview.tap()
                require(app.navigationBars.matching(NSPredicate(format: "label ENDSWITH %@", "v1")).firstMatch)
            }
        }
    }

    // Saved acknowledgment must be visible on reopen and only change through an explicit replacement.
    func testSavedAcknowledgmentReopensAndReplacementCanBeCancelled() throws {
        launch(arguments: ["--ui-testing", "--screenshot-fixture", "complete"])
        openFixtureWorkflow(named: "Complete Fixture Sedan")
        app.buttons["Review report"].tap()
        app.buttons["report.acknowledgment"].tap()
        let name = app.staticTexts["acknowledgment.savedName"]
        scrollUntilHittable(name)
        XCTAssertEqual(name.label, "Taylor Fixture")
        let recordedAt = app.staticTexts["acknowledgment.savedTime"]
        require(recordedAt)
        let savedTime = recordedAt.label
        require(app.descendants(matching: .any).matching(identifier: "acknowledgment.savedSignature").firstMatch)
        XCTAssertFalse(app.textFields["Customer name"].exists)
        tapReachable(app.buttons["acknowledgment.replace"])
        scrollUntilHittable(app.buttons["acknowledgment.cancelReplacement"])
        app.buttons["acknowledgment.cancelReplacement"].tap()
        XCTAssertEqual(recordedAt.label, savedTime)
        XCTAssertEqual(name.label, "Taylor Fixture")
        tapReachable(app.buttons["acknowledgment.replace"])
        scrollUntilHittable(app.buttons["Customer unavailable"])
        app.buttons["Customer unavailable"].tap()
        app.alerts.textFields.firstMatch.typeText("Customer left keys at office")
        app.alerts.buttons["Record"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["report.acknowledgment"].tap()
        let reason = app.staticTexts["acknowledgment.unavailableReason"]
        scrollUntilHittable(reason)
        XCTAssertEqual(reason.label, "Customer left keys at office")
        XCTAssertFalse(app.textFields["Customer name"].exists)
        capture("saved-unavailable-acknowledgment")
    }

    func testCleanLaunchCreatesSearchableJobAndOpensWorkflow() throws {
        launch(arguments: ["--ui-testing"])

        require(app.navigationBars["Set up your business"])
        capture("setup")
        app.textFields["Business name"].tap()
        app.textFields["Business name"].typeText("Fixture Detail")
        require(app.buttons["setup.logoPicker"])
        let firstService = app.textFields["setup.service.0"]
        require(firstService)
        firstService.tap()
        firstService.typeText(" Mobile")
        require(app.buttons["setup.templatePicker"])
        app.buttons["Save"].tap()

        require(app.navigationBars["Jobs"])
        app.buttons["New job"].tap()
        require(app.navigationBars["New job"])
        let editedService = app.switches
            .matching(NSPredicate(format: "label CONTAINS %@", "Mobile"))
            .firstMatch
        require(editedService)
        XCTAssertEqual(editedService.value as? String, "1", "The edited onboarding default service should be selected for a new job.")
        capture("new-job")
        app.textFields["Vehicle"].tap()
        app.textFields["Vehicle"].typeText("QA-17 Sedan")
        require(app.keyboards.buttons["Done"])
        app.keyboards.buttons["Done"].tap()
        let create = app.buttons["newJob.create"]
        scrollUntilHittable(create)
        create.tap()

        require(app.staticTexts["QA-17 Sedan"])
        capture("list")
        let search = activateSearch()
        search.typeText("QA-17")
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
        dismissDraftPreview()

        app.buttons["report.seal"].tap()
        require(app.buttons["report.confirmSeal"])
        app.buttons["report.confirmSeal"].tap()
        let version = reportVersion()
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
        let version = reportVersion()
        require(version)
        app.buttons["report.createRevision"].tap()
        require(app.navigationBars["Report"])
        XCTAssertTrue(version.exists, "Existing report history must stay reachable while a revision is in progress.")
        capture("revision-history")
    }

    func testBackupExportCanBeCancelledAndTrashCanBeRestored() throws {
        launch(arguments: ["--ui-testing", "--screenshot-fixture", "trash"])

        require(app.buttons["Settings"].firstMatch)
        app.buttons["Settings"].firstMatch.tap()
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
        require(app.buttons["Jobs"].firstMatch)
        app.buttons["Jobs"].firstMatch.tap()
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
        app.launchArguments = arguments + [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
        ]
        app.launchEnvironment = ["XCUI_TESTING": "1"]
        app.launch()
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        require(field)
        field.tap()
        let existing = field.value as? String ?? ""
        if !existing.isEmpty { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count)) }
        field.typeText(text)
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

    private func activateSearch() -> XCUIElement {
        let search = app.searchFields["Customer, vehicle, or plate"]
        if !search.exists {
            require(app.buttons["Search"].firstMatch)
            app.buttons["Search"].firstMatch.tap()
        }
        require(search)
        search.tap()
        return search
    }

    private func reportVersion() -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "report.version."))
            .firstMatch
    }

    private func scrollUntilHittable(_ element: XCUIElement, attempts: Int = 4, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<attempts where !element.isHittable {
            app.swipeUp()
        }
        // Back preserves a parent's scroll position; an earlier action can now be above the viewport.
        for _ in 0..<(attempts * 2) where !element.isHittable {
            app.swipeDown()
        }
        XCTAssertTrue(element.isHittable, "Expected \(element) to be reachable after scrolling.", file: file, line: line)
    }

    private func tapReachable(_ element: XCUIElement) {
        scrollUntilHittable(element)
        element.tap()
    }

    private func returnToJobs() {
        for _ in 0..<3 where !app.navigationBars["Jobs"].exists {
            let back = app.navigationBars.buttons.firstMatch
            require(back)
            back.tap()
        }
        require(app.navigationBars["Jobs"])
    }

    private func dismissDraftPreview() {
        let close = app.navigationBars["Draft preview"].buttons["Close"]
        require(close)
        close.tap()
        require(app.navigationBars["Report"])
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
        let picker = app.descendants(matching: .any)["Browse View (Picker)"]
        if picker.waitForExistence(timeout: 8) { return picker }
        let navigationBar = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
        if navigationBar.waitForExistence(timeout: 4) { return navigationBar }
        XCTFail("Backup export must present the real Files document picker process on iPhone or iPad.")
        return app.otherElements.firstMatch
    }

    private func dismissSharePresentation(_ presentation: XCUIElement) {
        dismissSystemPresentation(presentation, controls: ["Close", "Cancel"])
    }

    private func dismissFileExporterPresentation(_ presentation: XCUIElement) {
        let cancel = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Cancel"))
            .firstMatch
        require(cancel)
        cancel.tap()
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
