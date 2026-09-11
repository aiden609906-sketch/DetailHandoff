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
            let afterRoute = scrollUntilHittable(
                { app.buttons["workflow.editAfterCapture"] },
                in: verticalScroll("workflow.verticalScroll")
            )
            afterRoute.tap()
            require(app.navigationBars["After photos"])
            let afterRetake = scrollUntilHittable(
                { app.buttons["capture.camera.front"] },
                in: verticalScroll("capture.verticalScroll")
            )
            XCTAssertTrue(afterRetake.isEnabled)
            app.navigationBars.buttons.firstMatch.tap()
            let beforeRoute = scrollUntilHittable(
                { app.buttons["workflow.editBeforeCapture"] },
                in: verticalScroll("workflow.verticalScroll"),
                preferredDirection: .down
            )
            beforeRoute.tap()
            require(app.navigationBars["Before photos"])
            XCTAssertTrue(app.buttons["capture.camera.front"].isEnabled)
            let remove = scrollUntilHittable(
                { app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "capture.remove.rear.")).firstMatch },
                in: verticalScroll("capture.verticalScroll")
            )
            XCTAssertEqual(app.staticTexts["capture.count.rear"].label, "1 photo")
            remove.tap()
            XCTAssertEqual(app.staticTexts["capture.count.rear"].label, "0 photos")
            let skip = revealControlBelowVisibleAnchor(
                { app.buttons["capture.skip.rear"] },
                anchor: app.staticTexts["capture.count.rear"],
                in: verticalScroll("capture.verticalScroll")
            )
            let skipBeforeAction = skipDiagnosticCheckpoint(
                named: revision ? "revision-skip-before-action" : "review-skip-before-action"
            )
            tapAtCenter(skip)
            waitForOneSecondDiagnosticCheckpoint(named: "skip-post-action")
            let skipAfterOneSecond = skipDiagnosticCheckpoint(
                named: revision ? "revision-skip-after-1s" : "review-skip-after-1s"
            )
            let prompt = app.alerts["Skip this view"]
            requireSkipPrompt(
                prompt,
                beforeAction: skipBeforeAction,
                afterOneSecond: skipAfterOneSecond
            )
            prompt.textFields.firstMatch.typeText("Rechecked before handoff")
            prompt.buttons["Save"].tap()
            require(app.staticTexts["Skipped: Rechecked before handoff"])
            capture(revision ? "revision-before-correction" : "review-before-correction")
            app.navigationBars.buttons.firstMatch.tap()
            let review = scrollUntilHittable(
                {
                    app.descendants(matching: .any)
                        .matching(identifier: "workflow.report")
                        .firstMatch
                },
                in: verticalScroll("workflow.verticalScroll"),
                preferredDirection: .down
            )
            let reportBeforeAction = reportDiagnosticCheckpoint(named: "review-report-before-action")
            review.tap()
            waitForOneSecondDiagnosticCheckpoint(named: "review-report-post-action")
            let reportAfterOneSecond = reportDiagnosticCheckpoint(named: "review-report-after-1s")
            requireReportScreen(
                beforeAction: reportBeforeAction,
                afterOneSecond: reportAfterOneSecond
            )
            app.buttons["report.seal"].tap()
            confirmSeal()
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
            confirmSeal()
            require(reportVersion())
            let expectedVersion = revision ? "Version 2" : "Version 1"
            require(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", expectedVersion)).firstMatch)
            if revision {
                let originalPreview = scrollUntilHittable(
                    {
                        app.descendants(matching: .any)
                            .matching(NSPredicate(format: "label == %@", "Preview Version 1"))
                            .firstMatch
                    },
                    in: verticalScroll("report.verticalScroll")
                )
                tapAtCenter(originalPreview)
                let originalPDF = app.descendants(matching: .any)
                    .matching(NSPredicate(format: "identifier == %@ AND label ENDSWITH %@", "report.pdfPreview", "v1"))
                    .firstMatch
                require(originalPDF)
            }
        }
    }

    // Saved acknowledgment must be visible on reopen and only change through an explicit replacement.
    func testSavedAcknowledgmentReopensAndReplacementCanBeCancelled() throws {
        launch(arguments: ["--ui-testing", "--screenshot-fixture", "complete"])
        openFixtureWorkflow(named: "Complete Fixture Sedan")
        let report = scrollUntilHittable(
            {
                app.descendants(matching: .any)
                    .matching(identifier: "workflow.report")
                    .firstMatch
            },
            in: verticalScroll("workflow.verticalScroll")
        )
        let reportBeforeAction = reportDiagnosticCheckpoint(named: "saved-ack-report-before-action")
        report.tap()
        waitForOneSecondDiagnosticCheckpoint(named: "saved-ack-report-post-action")
        let reportAfterOneSecond = reportDiagnosticCheckpoint(named: "saved-ack-report-after-1s")
        requireReportScreen(
            beforeAction: reportBeforeAction,
            afterOneSecond: reportAfterOneSecond
        )
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
        let newJobScroll = verticalScroll("newJob.verticalScroll")
        let editedService = scrollUntilHittable(
            {
                app.switches
                    .matching(NSPredicate(format: "label CONTAINS %@", "Mobile"))
                    .firstMatch
            },
            in: newJobScroll
        )
        XCTAssertEqual(editedService.value as? String, "1", "The edited onboarding default service should be selected for a new job.")
        capture("new-job")
        let vehicle = scrollUntilHittable(
            { app.textFields["Vehicle"] },
            in: newJobScroll,
            preferredDirection: .down
        )
        vehicle.tap()
        vehicle.typeText("QA-17 Sedan")
        require(app.keyboards.buttons["Done"])
        app.keyboards.buttons["Done"].tap()
        let create = scrollUntilHittable(
            { app.buttons["newJob.create"] },
            in: newJobScroll
        )
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
        let report = scrollUntilHittable(
            {
                app.descendants(matching: .any)
                    .matching(identifier: "workflow.report")
                    .firstMatch
            },
            in: verticalScroll("workflow.verticalScroll"),
            preferredDirection: .down
        )
        let reportBeforeAction = reportDiagnosticCheckpoint(named: "complete-report-before-action")
        report.tap()
        waitForOneSecondDiagnosticCheckpoint(named: "complete-report-post-action")
        let reportAfterOneSecond = reportDiagnosticCheckpoint(named: "complete-report-after-1s")
        requireReportScreen(
            beforeAction: reportBeforeAction,
            afterOneSecond: reportAfterOneSecond
        )
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
        confirmSeal()
        let version = reportVersion()
        XCTAssertTrue(version.waitForExistence(timeout: 12), "Sealing a valid fixture should create a stored version.")
        capture("sealed-version")

        let share = scrollUntilHittable(
            {
                app.descendants(matching: .any)
                    .matching(NSPredicate(format: "label == %@", "Share Version 1"))
                    .firstMatch
            },
            in: verticalScroll("report.verticalScroll")
        )
        tapAtCenter(share)
        let sharePresentation = requireSharePresentation()
        capture("share-sheet")
        dismissSharePresentation(sharePresentation)
        requireDismissed(sharePresentation.marker, message: "Cancelling share should dismiss the system activity presentation.")
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
        requireDismissed(fileExporterPresentation.marker, message: "Cancelling backup export should dismiss the Files exporter surface.")
        requireNotHittable(fileExporterPresentation.cancel, message: "Cancelling backup export should hide the document picker's Cancel action.")
        let exportButton = app.buttons["backup.export"]
        requireHittable(exportButton, message: "Cancelling backup export must return interaction to the Backup screen.")

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
            "--ui-diagnostics",
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
        assertModernAppWindowGeometry()
        capture("fixture-list")
        app.staticTexts[vehicle].tap()
        require(app.navigationBars[vehicle])
        capture("workflow")
    }

    private func assertModernAppWindowGeometry(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let appWindow = app.windows.firstMatch
        guard appWindow.waitForExistence(timeout: 8) else {
            XCTFail(
                "The app window must exist before validating full-screen geometry.",
                file: file,
                line: line
            )
            return
        }
        let frame = appWindow.frame
        let shortSide = min(frame.width, frame.height)
        let longSide = max(frame.width, frame.height)
        XCTAssertTrue(
            shortSide >= 375 && longSide >= 667,
            "Expected a modern full-screen app window of at least 375x667 points; observed \(frame).",
            file: file,
            line: line
        )
    }

    private func openCaptureScreen() {
        require(app.staticTexts["Capture Fixture Coupe"])
        app.staticTexts["Capture Fixture Coupe"].tap()
        require(app.navigationBars["Capture Fixture Coupe"])
        let captureButton = scrollUntilHittable(
            { app.buttons["workflow.openBeforeCapture"] },
            in: verticalScroll("workflow.verticalScroll")
        )
        captureButton.tap()
        require(app.navigationBars["Before photos"])
        capture("capture")
        returnToJobs()
    }

    private func openFindingsScreen() {
        let findings = scrollUntilHittable(
            { app.buttons["workflow.findings"] },
            in: verticalScroll("workflow.verticalScroll")
        )
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

    private enum ScrollDirection {
        case up
        case down
    }

    @discardableResult
    private func scrollUntilHittable(
        _ element: XCUIElement,
        preferredDirection: ScrollDirection = .up,
        attempts: Int = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        scrollUntilHittable(
            { element },
            in: app,
            preferredDirection: preferredDirection,
            attempts: attempts,
            file: file,
            line: line
        )
    }

    @discardableResult
    private func scrollUntilHittable(
        _ resolveElement: () -> XCUIElement,
        in scrollContainer: XCUIElement,
        preferredDirection: ScrollDirection = .up,
        attempts: Int = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        require(scrollContainer, file: file, line: line)
        var element = resolveElement()
        if element.isHittable { return element }
        for _ in 0..<attempts {
            switch preferredDirection {
            case .up: scrollContainer.swipeUp()
            case .down: scrollContainer.swipeDown()
            }
            element = resolveElement()
            if element.isHittable { return element }
        }
        XCTAssertTrue(element.isHittable, "Expected \(element) to be reachable after scrolling.", file: file, line: line)
        return element
    }

    @discardableResult
    private func revealControlBelowVisibleAnchor(
        _ resolveElement: () -> XCUIElement,
        anchor: XCUIElement,
        in scrollContainer: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        var element = resolveElement()
        guard scrollContainer.waitForExistence(timeout: 8) else {
            XCTFail("The named capture scroll container must exist before revealing a slot control.", file: file, line: line)
            return element
        }
        guard anchor.waitForExistence(timeout: 8) else {
            XCTFail("The rear slot anchor must exist before revealing its control.", file: file, line: line)
            return element
        }
        let windowFrame = app.windows.firstMatch.frame
        let scrollFrame = scrollContainer.frame
        guard !scrollFrame.isEmpty else {
            XCTFail("The named capture scroll container must have a visible frame.", file: file, line: line)
            return element
        }

        for _ in 0..<3 {
            let anchorFrame = anchor.frame
            let anchorCenter = CGPoint(x: anchorFrame.midX, y: anchorFrame.midY)
            if !anchorFrame.isEmpty,
               windowFrame.contains(anchorCenter),
               scrollFrame.contains(anchorCenter) {
                break
            }

            let anchorIsAbove = !anchorFrame.isEmpty && anchorFrame.midY < scrollFrame.midY
            let startY = anchorIsAbove ? 0.35 : 0.65
            let destinationY = anchorIsAbove ? 0.55 : 0.45
            let start = scrollContainer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
            let destination = scrollContainer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: destinationY))
            start.press(forDuration: 0.05, thenDragTo: destination)
        }

        let visibleAnchorFrame = anchor.frame
        let visibleAnchorCenter = CGPoint(x: visibleAnchorFrame.midX, y: visibleAnchorFrame.midY)
        guard !visibleAnchorFrame.isEmpty,
              windowFrame.intersects(visibleAnchorFrame),
              scrollFrame.intersects(visibleAnchorFrame),
              windowFrame.contains(visibleAnchorCenter),
              scrollFrame.contains(visibleAnchorCenter) else {
            XCTFail("The rear slot anchor must be visible inside the named capture scroll container.", file: file, line: line)
            return element
        }
        if element.isHittable { return element }

        let travel = min(120, scrollFrame.height * 0.2)
        let destinationY = max(scrollFrame.minY + 1, visibleAnchorFrame.midY - travel)
        let destinationOffset = (destinationY - scrollFrame.minY) / scrollFrame.height
        let start = anchor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let destination = scrollContainer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: destinationOffset))
        for _ in 0..<3 {
            start.press(forDuration: 0.05, thenDragTo: destination)
            element = resolveElement()
            if element.isHittable { return element }
        }

        XCTAssertTrue(element.isHittable, "Expected the control below the visible slot anchor to become reachable after bounded, card-local scrolling.", file: file, line: line)
        return element
    }

    private func tapReachable(_ element: XCUIElement, preferredDirection: ScrollDirection = .up) {
        let reachableElement = scrollUntilHittable(element, preferredDirection: preferredDirection)
        tapAtCenter(reachableElement)
    }

    private func tapReachable(
        _ resolveElement: () -> XCUIElement,
        in scrollContainer: XCUIElement,
        preferredDirection: ScrollDirection = .up,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = scrollUntilHittable(
            resolveElement,
            in: scrollContainer,
            preferredDirection: preferredDirection,
            file: file,
            line: line
        )
        XCTAssertTrue(element.isHittable, "The freshly resolved element must remain hittable before tapping.", file: file, line: line)
        tapAtCenter(element)
    }

    private func tapAtCenter(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.isHittable, "The element must be hittable before its visible center is tapped.", file: file, line: line)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func verticalScroll(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    private func confirmSeal() {
        let confirmation = app.buttons
            .matching(NSPredicate(format: "identifier == %@", "report.confirmSeal"))
            .firstMatch
        require(confirmation)
        XCTAssertTrue(confirmation.isHittable, "The visible seal confirmation action must be hittable.")
        confirmation.tap()
    }

    private func requireReportScreen(
        beforeAction: DiagnosticCheckpoint,
        afterOneSecond: DiagnosticCheckpoint
    ) {
        let reportScroll = verticalScroll("report.verticalScroll")
        let appeared = reportScroll.waitForExistence(timeout: 8)
        if !appeared {
            attachDiagnostic(beforeAction)
            attachDiagnostic(afterOneSecond)
            attachDiagnostic(reportDiagnosticCheckpoint(named: "\(beforeAction.name)-timeout"))
        }
        XCTAssertTrue(appeared, "Expected \(reportScroll) to exist.")
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

    private struct SharePresentation {
        let marker: XCUIElement
        let cancel: XCUIElement
    }

    private func requireSharePresentation() -> SharePresentation {
        let roots = [
            XCUIApplication(bundleIdentifier: "com.apple.springboard"),
            app
        ]
        let activityPredicate = NSPredicate(
            format: "label == %@ OR label == %@ OR label == %@",
            "AirDrop",
            "Copy",
            "Save to Files"
        )
        let cancelPredicate = NSPredicate(format: "label == %@ OR label == %@", "Close", "Cancel")

        for root in roots {
            let marker = root.descendants(matching: .any)
                .matching(activityPredicate)
                .firstMatch
            guard marker.waitForExistence(timeout: 4) else { continue }
            let cancel = root.buttons.matching(cancelPredicate).firstMatch
            guard cancel.waitForExistence(timeout: 2), cancel.isHittable else { continue }
            return SharePresentation(marker: marker, cancel: cancel)
        }

        XCTFail("Share must expose a public system activity together with a hittable Close or Cancel button.")
        return SharePresentation(
            marker: app.descendants(matching: .any).matching(activityPredicate).firstMatch,
            cancel: app.buttons.matching(cancelPredicate).firstMatch
        )
    }

    private struct FileExporterPresentation {
        let marker: XCUIElement
        let cancel: XCUIElement
    }

    private struct DiagnosticApplicationRoot {
        let name: String
        let application: XCUIApplication
    }

    private func requireFileExporterPresentation() -> FileExporterPresentation {
        let roots = [
            DiagnosticApplicationRoot(
                name: "DocumentsApp (com.apple.DocumentsApp)",
                application: XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
            ),
            DiagnosticApplicationRoot(
                name: "SpringBoard (com.apple.springboard)",
                application: XCUIApplication(bundleIdentifier: "com.apple.springboard")
            ),
            DiagnosticApplicationRoot(name: "DetailHandoff target app", application: app)
        ]
        let exporterPredicate = NSPredicate(
            format: "label == %@ OR label == %@ OR label BEGINSWITH %@",
            "Save",
            "Save as",
            "DetailHandoff-backup"
        )
        let cancelPredicate = NSPredicate(format: "label == %@", "Cancel")
        let windowFrame = app.windows.firstMatch.frame
        var failureCheckpoints: [DiagnosticCheckpoint] = []

        for (rootIndex, diagnosticRoot) in roots.enumerated() {
            let root = diagnosticRoot.application
            guard isRunning(root.state) else { continue }
            let marker = root.descendants(matching: .any)
                .matching(exporterPredicate)
                .firstMatch
            guard marker.waitForExistence(timeout: 4) else { continue }
            let markerFrame = marker.frame
            guard !markerFrame.isEmpty, windowFrame.intersects(markerFrame) else { continue }
            let directCancel = root.buttons.matching(cancelPredicate).firstMatch
            if directCancel.waitForExistence(timeout: 1), directCancel.isHittable {
                return FileExporterPresentation(marker: marker, cancel: directCancel)
            }

            // Compact iPhone document pickers can replace the visible Cancel
            // button with a Browse back button. Return to the picker root so
            // XCTest can use the real, visible Cancel action there.
            let browseBack = root.navigationBars.buttons.matching(
                NSPredicate(format: "identifier == %@ AND label == %@", "BackButton", "Browse")
            ).firstMatch
            if browseBack.waitForExistence(timeout: 1), browseBack.isHittable {
                browseBack.tap()
                let rootCancel = root.buttons.matching(cancelPredicate).firstMatch
                if rootCancel.waitForExistence(timeout: 4), rootCancel.isHittable {
                    return FileExporterPresentation(marker: marker, cancel: rootCancel)
                }
                failureCheckpoints.append(
                    fileExporterDiagnosticCheckpoint(
                        named: "files-after-browse-back-root-\(rootIndex)",
                        roots: roots,
                        selectedRootIndex: rootIndex,
                        windowFrame: windowFrame,
                        exporterPredicate: exporterPredicate,
                        cancelPredicate: cancelPredicate
                    )
                )
            }
            failureCheckpoints.append(
                fileExporterDiagnosticCheckpoint(
                    named: "files-marker-accepted-root-\(rootIndex)",
                    roots: roots,
                    selectedRootIndex: rootIndex,
                    windowFrame: windowFrame,
                    exporterPredicate: exporterPredicate,
                    cancelPredicate: cancelPredicate
                )
            )

            let publicMore = root.buttons["More"].firstMatch
            let menuButton: XCUIElement?
            if publicMore.waitForExistence(timeout: 1), publicMore.isHittable {
                menuButton = publicMore
            } else {
                let cancelLabel = root.descendants(matching: .any)
                    .matching(cancelPredicate)
                    .firstMatch
                if cancelLabel.waitForExistence(timeout: 1) {
                    let labelFrame = cancelLabel.frame
                    let labelCenter = CGPoint(x: labelFrame.midX, y: labelFrame.midY)
                    menuButton = !labelFrame.isEmpty && windowFrame.intersects(labelFrame)
                        ? root.navigationBars.buttons.allElementsBoundByIndex.first(where: {
                            $0.isHittable && $0.frame.contains(labelCenter)
                        })
                        : nil
                } else {
                    menuButton = nil
                }
            }
            guard let menuButton else { continue }
            menuButton.tap()
            failureCheckpoints.append(
                fileExporterDiagnosticCheckpoint(
                    named: "files-after-more-root-\(rootIndex)",
                    roots: roots,
                    selectedRootIndex: rootIndex,
                    windowFrame: windowFrame,
                    exporterPredicate: exporterPredicate,
                    cancelPredicate: cancelPredicate
                )
            )

            let menuCancel = root.buttons.matching(cancelPredicate).firstMatch
            if menuCancel.waitForExistence(timeout: 4), menuCancel.isHittable {
                return FileExporterPresentation(marker: marker, cancel: menuCancel)
            }
            let semanticMenuCancels = root.descendants(matching: .any)
                .matching(cancelPredicate)
                .allElementsBoundByIndex
            if let semanticMenuCancel = semanticMenuCancels.first(where: {
                $0.isHittable && !$0.frame.isEmpty && windowFrame.intersects($0.frame)
            }) {
                return FileExporterPresentation(marker: marker, cancel: semanticMenuCancel)
            }
        }

        if failureCheckpoints.isEmpty {
            failureCheckpoints.append(
                fileExporterDiagnosticCheckpoint(
                    named: "files-no-accepted-marker",
                    roots: roots,
                    selectedRootIndex: nil,
                    windowFrame: windowFrame,
                    exporterPredicate: exporterPredicate,
                    cancelPredicate: cancelPredicate
                )
            )
        }
        for checkpoint in failureCheckpoints {
            attachDiagnostic(checkpoint)
        }
        XCTFail("The real Files exporter must expose Save, Save as, or its backup filename and a real hittable Cancel action in the same root, directly, from Browse, or through its More menu.")
        return FileExporterPresentation(
            marker: app.descendants(matching: .any).matching(exporterPredicate).firstMatch,
            cancel: app.navigationBars.buttons.firstMatch
        )
    }

    private func dismissSharePresentation(_ presentation: SharePresentation) {
        presentation.cancel.tap()
    }

    private func dismissFileExporterPresentation(_ presentation: FileExporterPresentation) {
        presentation.cancel.tap()
    }

    private func requireDismissed(_ presentation: XCUIElement, message: String) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: presentation
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed, message)
    }

    private func requireNotHittable(_ element: XCUIElement, message: String) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == false"),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed, message)
    }

    private func requireHittable(_ element: XCUIElement, message: String) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed, message)
    }

    private struct DiagnosticCheckpoint {
        let name: String
        let screenshot: XCUIScreenshot
        let details: String
    }

    private func reportDiagnosticCheckpoint(named name: String) -> DiagnosticCheckpoint {
        let checkpointUptime = ProcessInfo.processInfo.systemUptime
        let screenshot = app.screenshot()
        let reportQuery = app.descendants(matching: .any)
            .matching(identifier: "workflow.report")
        let workflowScroll = verticalScroll("workflow.verticalScroll")
        let reportScroll = verticalScroll("report.verticalScroll")
        let window = app.windows.firstMatch
        let details = [
            "checkpoint-system-uptime=\(String(format: "%.3f", checkpointUptime))",
            "tap-api=XCUIElement.tap()",
            "app-window \(elementSummary(window))",
            "workflow-scroll \(elementSummary(workflowScroll))",
            "report-scroll \(elementSummary(reportScroll))",
            elementSummaries(reportQuery, heading: "workflow.report candidates"),
            elementSummaries(app.navigationBars, heading: "navigation bars"),
            "app.debugDescription:\n\(app.debugDescription)"
        ].joined(separator: "\n")
        return DiagnosticCheckpoint(name: name, screenshot: screenshot, details: details)
    }

    private func skipDiagnosticCheckpoint(named name: String) -> DiagnosticCheckpoint {
        let screenshot = app.screenshot()
        let skipQuery = app.descendants(matching: .any)
            .matching(identifier: "capture.skip.rear")
        let skip = skipQuery.firstMatch
        let transitionSignal = app.descendants(matching: .any)
            .matching(identifier: "diagnostic.capture.skipTransition")
            .firstMatch
        let details = [
            "checkpoint-system-uptime=\(String(format: "%.3f", ProcessInfo.processInfo.systemUptime))",
            "tap-api=coordinate(normalizedOffset: 0.5,0.5)",
            "computed-tap-point=(x: \(format(skip.frame.midX)), y: \(format(skip.frame.midY)))",
            "skip-transition-signal \(elementSummary(transitionSignal))",
            "app-window \(elementSummary(app.windows.firstMatch))",
            "capture-scroll \(elementSummary(verticalScroll("capture.verticalScroll")))",
            "rear-anchor \(elementSummary(app.staticTexts["capture.count.rear"]))",
            elementSummaries(skipQuery, heading: "capture.skip.rear candidates"),
            elementSummaries(app.alerts, heading: "alerts"),
            elementSummaries(app.navigationBars, heading: "navigation bars"),
            "app.debugDescription:\n\(app.debugDescription)"
        ].joined(separator: "\n")
        return DiagnosticCheckpoint(name: name, screenshot: screenshot, details: details)
    }

    private func requireSkipPrompt(
        _ prompt: XCUIElement,
        beforeAction: DiagnosticCheckpoint,
        afterOneSecond: DiagnosticCheckpoint,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let appeared = prompt.waitForExistence(timeout: 8)
        if !appeared {
            attachDiagnostic(beforeAction)
            attachDiagnostic(afterOneSecond)
            attachDiagnostic(skipDiagnosticCheckpoint(named: "\(beforeAction.name)-timeout"))
        }
        XCTAssertTrue(appeared, "Expected \(prompt) to exist.", file: file, line: line)
    }

    private func fileExporterDiagnosticCheckpoint(
        named name: String,
        roots: [DiagnosticApplicationRoot],
        selectedRootIndex: Int?,
        windowFrame: CGRect,
        exporterPredicate: NSPredicate,
        cancelPredicate: NSPredicate
    ) -> DiagnosticCheckpoint {
        var sections = [
            "fixture-data-only=true",
            "selected-root-index=\(selectedRootIndex.map { String($0) } ?? "none")",
            "app-window-frame=\(frameSummary(windowFrame))"
        ]
        for (index, diagnosticRoot) in roots.enumerated() {
            let root = diagnosticRoot.application
            let prefix = "root[\(index)] \(diagnosticRoot.name)"
            let rootState = root.state
            guard isRunning(rootState) else {
                sections.append(
                    "\(prefix) state=\(String(describing: rootState)); queries skipped because not running"
                )
                continue
            }
            sections.append("\(prefix) state=\(String(describing: rootState))")
            sections.append(
                elementSummaries(
                    root.descendants(matching: .any).matching(exporterPredicate),
                    heading: "\(prefix) exporter markers",
                    windowFrame: windowFrame
                )
            )
            sections.append(
                elementSummaries(
                    root.descendants(matching: .any).matching(cancelPredicate),
                    heading: "\(prefix) Cancel candidates",
                    windowFrame: windowFrame
                )
            )
            sections.append(
                elementSummaries(
                    root.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "More")),
                    heading: "\(prefix) More candidates",
                    windowFrame: windowFrame
                )
            )
            sections.append("\(prefix).debugDescription:\n\(root.debugDescription)")
        }
        let targetAppState = app.state
        if isRunning(targetAppState) {
            sections.append("target-app.debugDescription:\n\(app.debugDescription)")
            sections.append("backup.export \(elementSummary(app.buttons["backup.export"], windowFrame: windowFrame))")
            sections.append(elementSummaries(app.navigationBars, heading: "target-app navigation bars", windowFrame: windowFrame))
        } else {
            sections.append(
                "target-app state=\(String(describing: targetAppState)); queries skipped because not running"
            )
        }
        return DiagnosticCheckpoint(name: name, screenshot: app.screenshot(), details: sections.joined(separator: "\n"))
    }

    private func isRunning(_ state: XCUIApplication.State) -> Bool {
        state == .runningForeground || state == .runningBackground
    }

    private func elementSummaries(
        _ query: XCUIElementQuery,
        heading: String,
        windowFrame: CGRect? = nil
    ) -> String {
        let elements = query.allElementsBoundByIndex
        guard !elements.isEmpty else { return "\(heading): none" }
        return (["\(heading): count=\(elements.count)"] + elements.enumerated().map { index, element in
            "[\(index)] \(elementSummary(element, windowFrame: windowFrame))"
        }).joined(separator: "\n")
    }

    private func elementSummary(_ element: XCUIElement, windowFrame: CGRect? = nil) -> String {
        guard element.exists else { return "exists=false" }
        let elementFrame = element.frame
        let geometry: String
        if let windowFrame {
            geometry = " frameEmpty=\(elementFrame.isEmpty) intersectsAppWindow=\(windowFrame.intersects(elementFrame))"
        } else {
            geometry = ""
        }
        let value = element.value.map { quoted(String(describing: $0)) } ?? "nil"
        return "type=\(String(describing: element.elementType)) identifier=\(quoted(element.identifier)) label=\(quoted(element.label)) value=\(value) exists=true enabled=\(element.isEnabled) hittable=\(element.isHittable) frame=\(frameSummary(elementFrame))\(geometry)"
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

    private func attachDiagnostic(_ checkpoint: DiagnosticCheckpoint) {
        let screenshot = XCTAttachment(screenshot: checkpoint.screenshot)
        screenshot.name = "diagnostic-\(checkpoint.name)-screenshot"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let details = XCTAttachment(string: checkpoint.details)
        details.name = "diagnostic-\(checkpoint.name)-hierarchy.txt"
        details.lifetime = .keepAlways
        add(details)
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
