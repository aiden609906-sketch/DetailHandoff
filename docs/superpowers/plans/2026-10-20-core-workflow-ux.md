# Core Workflow UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make job and finding creation prominent, make the workflow scrollbar track real movement, support unrestricted one-or-many photo capture, expose photo-pair review before completion acknowledgment, and simplify customer-facing report identity.

**Architecture:** Preserve the SwiftData and `CaptureDocument` schemas. Add an iOS 17-compatible scroll-offset observer, one reusable SwiftUI creation action, and explicit capture-flow state around the existing repository and system camera/photo picker; reuse `PhotoPairView`. Keep PDF audit metadata while centralizing conditional provider-contact rendering.

**Tech Stack:** Swift 6, SwiftUI, UIKit interoperability, PhotosUI, SwiftData, PDFKit/XCTest, XCUITest, XcodeGen, iOS 17+

**Spec:** `docs/superpowers/specs/2026-10-20-core-workflow-ux-design.md`

## Global Constraints

- Keep the iOS 17.0 deployment target; do not use iOS 18-only scroll APIs.
- Do not change `CaptureDocument.currentSchemaVersion` or migrate existing jobs.
- Preserve report numbers, revisions, frozen snapshots, signatures, backups, exports, and immutable-job rules.
- Append every camera/library image through `CaptureRepository.addPhoto`; never replace implicitly.
- Set PhotosPicker `maxSelectionCount` to `nil`, the system-supported maximum, instead of an app-defined count.
- Use red-green-refactor for every production behavior.

## Review Focus

- When workflow steps fit, hide the custom indicator; test in `WorkflowProgressLayoutTests`.
- When search returns zero jobs, keep `Create new job` visible; test in `WorkflowUITests`.
- Camera cancellation adds nothing and does not offer another photo; test in `CapturePresentationStateTests`.
- Repeated photos in one slot/phase round-trip in capture order; test in `CaptureRepositoryTests`.
- Blank provider contacts leave no PDF labels while `Version N` remains; test in `ReportRepositoryTests`.

---

### Task 1: Track the real workflow scroll offset

**Files:**
- Create: `DetailHandoff/Features/Workflow/WorkflowScrollOffsetObserver.swift`
- Modify: `DetailHandoff/Features/Workflow/JobWorkflowView.swift`
- Modify: `DetailHandoffTests/WorkflowProgressLayoutTests.swift`
- Modify: `DetailHandoffUITests/WorkflowUITests.swift`

**Interfaces:**
- Produces: `WorkflowScrollOffsetObserver(horizontalOffset: Binding<CGFloat>)`, observing the enclosing `UIScrollView.contentOffset.x` without taking over its delegate.
- Consumes: `WorkflowProgressLayout.scrollIndicatorMetrics(...)` with `contentMinX = -horizontalOffset`.

- [ ] **Step 1: Write failing tests**

Add `testScrollIndicatorClampsObservedBounceOffsets()` for leading bounce, middle movement, and trailing overscroll. Add `testWorkflowIndicatorMovesAfterHorizontalDrag()` that reads the existing DEBUG/UI-testing diagnostic pattern before and after a real horizontal drag and asserts the thumb offset increases.

- [ ] **Step 2: Verify RED**

Run `xcodebuild test -project DetailHandoff.xcodeproj -scheme DetailHandoff -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DetailHandoffTests/WorkflowProgressLayoutTests -only-testing:DetailHandoffUITests/WorkflowUITests/testWorkflowIndicatorMovesAfterHorizontalDrag CODE_SIGNING_ALLOWED=NO`.

Expected: the diagnostic/real offset behavior is missing.

- [ ] **Step 3: Implement the observer and binding**

Use a coordinator-owned `NSKeyValueObservation`; install safely when the representable reaches an enclosing scroll view and invalidate on dismantle. Replace content-frame offset inference with `@State workflowHorizontalOffset`, but retain width preferences and the pure metrics function. Under DEBUG plus `XCUI_TESTING`, expose `diagnostic.workflow.scrollIndicator`; keep the production indicator hidden from VoiceOver.

- [ ] **Step 4: Verify GREEN and commit**

Run the Step 2 command, then commit:

```bash
git add DetailHandoff/Features/Workflow/WorkflowScrollOffsetObserver.swift DetailHandoff/Features/Workflow/JobWorkflowView.swift DetailHandoffTests/WorkflowProgressLayoutTests.swift DetailHandoffUITests/WorkflowUITests.swift
git commit -m "fix: synchronize workflow scroll indicator"
```

---

### Task 2: Promote job and finding creation

**Files:**
- Create: `DetailHandoff/DesignSystem/PrimaryCreationAction.swift`
- Modify: `DetailHandoff/Features/Jobs/JobsListView.swift`
- Modify: `DetailHandoff/Features/Findings/FindingsView.swift`
- Modify: `DetailHandoffUITests/WorkflowUITests.swift`
- Modify: `DetailHandoffUITests/ScreenshotTests.swift`

**Interfaces:**
- Produces: `PrimaryCreationAction(title:systemImage:action:)`, a full-width accent-colored, Dynamic Type-safe large button.
- Produces identifiers: `jobs.create` and `findings.create`.

- [ ] **Step 1: Write failing UI tests**

Require `jobs.create` before the first job, after a job exists, and with no search matches. Require `findings.create` on mutable findings and assert it is absent when finalized. Add iPhone/iPad large-text screenshot coverage.

- [ ] **Step 2: Verify RED**

Run the `WorkflowUITests` and `ScreenshotTests` targets; expect both identifiers to be absent.

- [ ] **Step 3: Implement the shared primary action**

Place the Jobs action as the first list row for every content state and remove the toolbar plus. Place the matching Findings action first when mutable and remove its toolbar plus. Preserve sheets, empty states, edit/delete behavior, and immutable read-only behavior.

- [ ] **Step 4: Verify GREEN and commit**

Run the focused UI tests, then commit:

```bash
git add DetailHandoff/DesignSystem/PrimaryCreationAction.swift DetailHandoff/Features/Jobs/JobsListView.swift DetailHandoff/Features/Findings/FindingsView.swift DetailHandoffUITests/WorkflowUITests.swift DetailHandoffUITests/ScreenshotTests.swift
git commit -m "ui: emphasize job and finding creation"
```

---

### Task 3: Support clear one-or-many photo addition

**Files:**
- Modify: `DetailHandoff/Features/Capture/CapturePresentationState.swift`
- Modify: `DetailHandoff/Features/Capture/CaptureView.swift`
- Modify: `DetailHandoffTests/CapturePresentationStateTests.swift`
- Modify: `DetailHandoffTests/CaptureRepositoryTests.swift`
- Modify: `DetailHandoffUITests/WorkflowUITests.swift`

**Interfaces:**
- Produces: `CapturePhotoContinuation` with `.none` and `.offerAnother(slotID:)`, selected only after a successful camera save.
- Produces: `CapturePresentationState.cameraContinuation(saved:slotID:) -> CapturePhotoContinuation`, so success and cancellation are testable without presenting a device camera.
- Produces identifiers: `capture.addPhotos.<slotID>`, `capture.takePhotos`, `capture.choosePhotos`, and `capture.takeAnother`.
- Consumes: existing pending actions, storage checks, `CameraPicker`, `EvidenceImport`, and `CaptureRepository.addPhoto`.

- [ ] **Step 1: Write failing unit and UI tests**

Add `testSuccessfulCameraSaveOffersAnotherForTheSameSlot()` and `testCameraCancellationDoesNotOfferAnother()`. Add `testMultiplePhotosForOneSlotAndPhaseRoundTripInOrder()` that appends four `wheels-tires` Before images and decodes four distinct records in insertion order. Require the unified Add photos source choices and assert `Retake` is absent.

- [ ] **Step 2: Verify RED**

Run the `CapturePresentationStateTests`, `CaptureRepositoryTests`, and the focused capture UI test. Expect continuation and unified action failures.

- [ ] **Step 3: Implement flexible addition**

Replace `Take photo`/`Retake` and `Import` with `Add photos` plus a source dialog. `Take photos` runs the current storage-checked camera. After a successful save, present `Take another photo` (recheck storage and reopen for the same slot) and `Done`; cancellation shows no continuation. Keep the array PhotosPicker and set `maxSelectionCount: nil`. Preserve sequential import and partial-failure behavior.

- [ ] **Step 4: Verify GREEN and commit**

Run the focused tests, then commit:

```bash
git add DetailHandoff/Features/Capture/CapturePresentationState.swift DetailHandoff/Features/Capture/CaptureView.swift DetailHandoffTests/CapturePresentationStateTests.swift DetailHandoffTests/CaptureRepositoryTests.swift DetailHandoffUITests/WorkflowUITests.swift
git commit -m "feat: support flexible multi-photo capture"
```

---

### Task 4: Expose photo pairs before completion acknowledgment

**Files:**
- Modify: `DetailHandoff/Features/Workflow/JobWorkflowView.swift`
- Modify: `DetailHandoff/Testing/UITestFixtures.swift`
- Modify: `DetailHandoffUITests/WorkflowUITests.swift`

**Interfaces:**
- Produces: `workflow.photoPairs` in `.awaitingCompletionAcknowledgment`.
- Consumes: unchanged `PhotoPairView(job:)`.

- [ ] **Step 1: Write a failing UI test**

Add an `awaiting-completion` fixture that stops after required After photos. Add `testCompletionAcknowledgmentStepCanInspectPhotoPairsAndReturn()` to require both completion acknowledgment and photo-pair actions, open pairs, verify Before/After, and return.

- [ ] **Step 2: Verify RED**

Run only that UI test; expect `workflow.photoPairs` to be absent.

- [ ] **Step 3: Reuse the existing pair link**

Group `Record completion acknowledgment` with a bordered `Inspect photo pairs` NavigationLink. Give all existing pair links the common identifier. Do not duplicate comparison UI inside `AcknowledgmentView`.

- [ ] **Step 4: Verify GREEN and commit**

Run the focused UI test, then commit:

```bash
git add DetailHandoff/Features/Workflow/JobWorkflowView.swift DetailHandoff/Testing/UITestFixtures.swift DetailHandoffUITests/WorkflowUITests.swift
git commit -m "feat: expose photo pairs before completion confirmation"
```

---

### Task 5: Simplify provider identity in the customer PDF

**Files:**
- Modify: `DetailHandoff/Features/Reports/ReportRenderer.swift`
- Modify: `DetailHandoff/Features/Onboarding/SetupView.swift`
- Modify: `DetailHandoff/Features/Settings/SettingsView.swift`
- Modify: `DetailHandoffTests/ReportRepositoryTests.swift`
- Modify: `DetailHandoffUITests/WorkflowUITests.swift`

**Interfaces:**
- Produces: `ReportRenderer.providerContactLines(phone:email:) -> [String]`.
- Preserves: report number, `Version N`, timestamp, provider name/logo, and all evidence/audit content.

- [ ] **Step 1: Write failing PDF and label tests**

Add `testPDFOmitsBlankProviderContactLabelsButKeepsReportRevision()` and `testFirstPageShowsProviderIdentityOnce()`. Use PDFKit first-page text to assert no blank `Phone:`/`Email:`, retain `Version 1`, show provider once, and still render nonblank contacts. Require `Customer-facing phone (optional)` and `Customer-facing email (optional)` in onboarding/settings UI tests.

- [ ] **Step 2: Verify RED**

Run focused `ReportRepositoryTests` and UI tests; expect duplicated identity, blank labels, and old field labels.

- [ ] **Step 3: Implement conditional identity**

Make page 1's running header report-oriented and use provider branding on subsequent pages. Render provider name once in the first-page identity block and render only nonblank contact lines. Keep report revision and timestamp untouched. Rename editable labels exactly as specified without changing stored fields or inferring Apple-account values.

- [ ] **Step 4: Verify GREEN and commit**

Run focused tests, then commit:

```bash
git add DetailHandoff/Features/Reports/ReportRenderer.swift DetailHandoff/Features/Onboarding/SetupView.swift DetailHandoff/Features/Settings/SettingsView.swift DetailHandoffTests/ReportRepositoryTests.swift DetailHandoffUITests/WorkflowUITests.swift
git commit -m "ui: simplify customer report identity"
```

---

### Task 6: Complete release verification

**Files:**
- Modify only if verification exposes a regression in the preceding task's owned files.

**Interfaces:**
- Consumes: Tasks 1-5.
- Produces: build, unit, iPhone UI, iPad UI, release-resource, and visual evidence for a TestFlight decision.

- [ ] **Step 1: Regenerate and inspect**

Run `xcodegen generate`, `git diff --check`, and `git status --short`. Expect no unintended generated changes or whitespace errors.

- [ ] **Step 2: Run full unit tests**

Run the CI-equivalent `xcodebuild test` command for `DetailHandoffTests` on an available iPhone simulator. Expect zero failures.

- [ ] **Step 3: Run all UI tests on both device families**

Run `DetailHandoffUITests` serially on an available iPhone and iPad. Expect zero failures on both.

- [ ] **Step 4: Build Release and inspect visuals**

Run the Release build and screenshot-fixture exclusion check from `.github/workflows/ios-build.yml`. Export attachments and inspect Jobs, Findings, capture, scrollbar leading/trailing positions, completion actions, and report first page.

- [ ] **Step 5: Verify the spec and commit fixture-only changes**

Check each spec success criterion against evidence. If only fixture/screenshot updates remain, commit them separately as `test: verify core workflow UX improvements`.

- [ ] **Step 6: Push and confirm GitHub Actions**

Push `main`, locate the matching `ios-build.yml` run, and run `gh run watch <run-id> --exit-status`. Require success for the exact head SHA before triggering TestFlight.
