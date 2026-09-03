# DetailHandoff Phase 1 Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a compilable iPhone/iPad SwiftUI foundation with SwiftData persistence, job creation, a searchable job list, and the complete job-status navigation skeleton.

**Architecture:** The app uses feature-oriented SwiftUI folders and a small SwiftData persistence layer. Phase 1 deliberately stops before camera capture, signatures, PDF generation, backup, and report sealing; later plans add those capabilities behind the stable `JobRecord` and `JobStatus` interfaces created here.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, XcodeGen, iOS/iPadOS 17+

**Spec:** `docs/superpowers/specs/2026-09-03-detailhandoff-design.md`

## Global Constraints

- Product name is `DetailHandoff` and the bundle identifier is `com.aiden609906.detailhandoff`.
- Deployment targets are iOS 17.0 and iPadOS 17.0.
- The interface is English-first, iPhone-first, and adaptive on iPad.
- V1 has no account, server, analytics SDK, ads, subscription, AI, or third-party runtime SDK.
- Data remains local; Phase 1 uses SwiftData with an on-device persistent container.
- The paid-download price is USD 9.99 and does not require StoreKit code inside the app.
- Every production type and file has one clear responsibility.
- Each task follows red-green-refactor and ends with a focused commit.

---

## Delivery Roadmap

The approved PRD contains several independently testable subsystems. Implement them as separate plans:

1. **Phase 1 — Foundation:** project, persistence, job list, new job, status navigation.
2. **Phase 2 — Capture:** photo templates, camera/import, before/after pairing, skips, manual findings.
3. **Phase 3 — Acknowledgment and Reports:** signature, customer-unavailable path, PDF, sealing, versions, sharing.
4. **Phase 4 — Data Safety:** backup/restore, export bundle, storage management, recently deleted.
5. **Phase 5 — Release:** accessibility, performance, TestFlight, privacy verification, App Store assets.

This plan implements Phase 1 only and leaves the repository in a working state suitable for Phase 2.

## File Map

```text
project.yml                                      XcodeGen project definition
.github/workflows/ios-build.yml                  macOS build and unit-test verification
DetailHandoff/App/DetailHandoffApp.swift         minimal entry point, then SwiftData container
DetailHandoff/App/RootView.swift                 first-run gate and tab navigation
DetailHandoff/Domain/JobStatus.swift             legal workflow states and transitions
DetailHandoff/Models/BusinessProfile.swift       persisted company setup record
DetailHandoff/Models/JobRecord.swift             persisted job record
DetailHandoff/Persistence/JobRepository.swift    job queries and mutations
DetailHandoff/Features/Onboarding/SetupView.swift first business setup
DetailHandoff/Features/Jobs/JobsListView.swift   searchable job list
DetailHandoff/Features/Jobs/NewJobView.swift     validated job form
DetailHandoff/Features/Workflow/JobWorkflowView.swift job progress and next action
DetailHandoff/DesignSystem/AppTheme.swift        colors, spacing, and reusable card style
DetailHandoff/Resources/Assets.xcassets/...      asset catalog metadata
DetailHandoffTests/JobStatusTests.swift          transition tests
DetailHandoffTests/JobRepositoryTests.swift      in-memory persistence tests
DetailHandoffTests/NewJobValidatorTests.swift    job-form validation tests
DetailHandoffTests/ProjectSmokeTests.swift       initial target smoke test
README.md                                        build and project-status instructions
```

---

### Task 1: Create the Xcode Project Definition and CI Build

**Files:**
- Create: `project.yml`
- Create: `.github/workflows/ios-build.yml`
- Create: `DetailHandoff/Resources/Assets.xcassets/Contents.json`
- Create: `DetailHandoff/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `DetailHandoff/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `DetailHandoff/App/DetailHandoffApp.swift`
- Create: `DetailHandoffTests/ProjectSmokeTests.swift`

**Interfaces:**
- Consumes: none
- Produces: Xcode scheme `DetailHandoff`, app target `DetailHandoff`, unit-test target `DetailHandoffTests`

- [ ] **Step 1: Add a failing repository structure check**

Run in PowerShell:

```powershell
$required = @(
  'project.yml',
  '.github/workflows/ios-build.yml',
  'DetailHandoff/Resources/Assets.xcassets/Contents.json',
  'DetailHandoff/App/DetailHandoffApp.swift',
  'DetailHandoffTests/ProjectSmokeTests.swift'
)
$missing = $required | Where-Object { -not (Test-Path -LiteralPath $_) }
if ($missing.Count -ne 0) { throw "Missing: $($missing -join ', ')" }
```

Expected: FAIL listing all three missing paths.

- [ ] **Step 2: Add the XcodeGen project definition**

Create `project.yml`:

```yaml
name: DetailHandoff
options:
  bundleIdPrefix: com.aiden609906
  deploymentTarget:
    iOS: "17.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
targets:
  DetailHandoff:
    type: application
    platform: iOS
    sources:
      - path: DetailHandoff
    resources:
      - path: DetailHandoff/Resources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.aiden609906.detailhandoff
        PRODUCT_NAME: DetailHandoff
        INFOPLIST_KEY_CFBundleDisplayName: DetailHandoff
        INFOPLIST_KEY_NSCameraUsageDescription: DetailHandoff uses the camera to document vehicle condition before and after service.
        INFOPLIST_KEY_NSPhotoLibraryUsageDescription: DetailHandoff lets you import vehicle photos selected by you.
        GENERATE_INFOPLIST_FILE: YES
        TARGETED_DEVICE_FAMILY: "1,2"
        SUPPORTS_MACCATALYST: NO
    scheme:
      testTargets:
        - DetailHandoffTests
  DetailHandoffTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: DetailHandoffTests
    dependencies:
      - target: DetailHandoff
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
```

- [ ] **Step 3: Add asset catalog metadata**

Create the root `Contents.json`:

```json
{
  "info": { "author": "xcode", "version": 1 }
}
```

Create `AccentColor.colorset/Contents.json`:

```json
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": { "alpha": "1.000", "blue": "0.950", "green": "0.380", "red": "0.100" }
      },
      "idiom": "universal"
    },
    {
      "appearances": [{ "appearance": "luminosity", "value": "dark" }],
      "color": {
        "color-space": "srgb",
        "components": { "alpha": "1.000", "blue": "1.000", "green": "0.580", "red": "0.300" }
      },
      "idiom": "universal"
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

Create `AppIcon.appiconset/Contents.json` with an empty universal icon definition so the development build emits no invalid-file error:

```json
{
  "images": [
    { "idiom": "universal", "platform": "ios", "size": "1024x1024" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

- [ ] **Step 4: Add the minimal app entry and smoke test**

Create `DetailHandoff/App/DetailHandoffApp.swift`:

```swift
import SwiftUI

@main
struct DetailHandoffApp: App {
    var body: some Scene {
        WindowGroup {
            Text("DetailHandoff")
                .accessibilityIdentifier("app-title")
        }
    }
}
```

Create `DetailHandoffTests/ProjectSmokeTests.swift`:

```swift
import XCTest
@testable import DetailHandoff

final class ProjectSmokeTests: XCTestCase {
    func testProductIdentity() {
        XCTAssertEqual("DetailHandoff", "DetailHandoff")
    }
}
```

- [ ] **Step 5: Add the macOS verification workflow**

Create `.github/workflows/ios-build.yml`:

```yaml
name: iOS Build

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install XcodeGen
        run: brew install xcodegen
      - name: Generate Xcode project
        run: xcodegen generate
      - name: Build for iOS Simulator
        run: >-
          xcodebuild
          -project DetailHandoff.xcodeproj
          -scheme DetailHandoff
          -destination 'generic/platform=iOS Simulator'
          CODE_SIGNING_ALLOWED=NO
          build
```

- [ ] **Step 6: Re-run the structure check**

Expected: PASS with exit code 0.

- [ ] **Step 7: Generate, build, and test on a Mac executor**

Run:

```bash
xcodegen generate
xcodebuild -project DetailHandoff.xcodeproj -scheme DetailHandoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild test -project DetailHandoff.xcodeproj -scheme DetailHandoff -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -only-testing:DetailHandoffTests/ProjectSmokeTests
```

Expected: project generation succeeds, the build reports `BUILD SUCCEEDED`, and the smoke test reports `TEST SUCCEEDED`.

- [ ] **Step 8: Commit project configuration**

```bash
git add project.yml .github/workflows/ios-build.yml DetailHandoff/App/DetailHandoffApp.swift DetailHandoff/Resources DetailHandoffTests/ProjectSmokeTests.swift
git commit -m "build: configure DetailHandoff iOS project"
```

---

### Task 2: Implement the Job Workflow State Machine

**Files:**
- Create: `DetailHandoff/Domain/JobStatus.swift`
- Create: `DetailHandoffTests/JobStatusTests.swift`

**Interfaces:**
- Consumes: none
- Produces: `enum JobStatus`, `JobStatus.next`, `JobStatus.canTransition(to:)`, `JobStatus.displayName`

- [ ] **Step 1: Write failing transition tests**

Create `DetailHandoffTests/JobStatusTests.swift`:

```swift
import XCTest
@testable import DetailHandoff

final class JobStatusTests: XCTestCase {
    func testHappyPathTransitionsAreAllowed() {
        let path: [JobStatus] = [
            .draft,
            .beforeCapture,
            .awaitingAcknowledgment,
            .inProgress,
            .afterCapture,
            .review,
            .finalized,
            .archived
        ]

        for pair in zip(path, path.dropFirst()) {
            XCTAssertTrue(pair.0.canTransition(to: pair.1))
            XCTAssertEqual(pair.0.next, pair.1)
        }
    }

    func testFinalizedCannotReturnToEditableState() {
        XCTAssertFalse(JobStatus.finalized.canTransition(to: .review))
        XCTAssertFalse(JobStatus.archived.canTransition(to: .draft))
    }

    func testDisplayNamesAreCustomerReadableEnglish() {
        XCTAssertEqual(JobStatus.beforeCapture.displayName, "Before photos")
        XCTAssertEqual(JobStatus.awaitingAcknowledgment.displayName, "Awaiting acknowledgment")
        XCTAssertEqual(JobStatus.finalized.displayName, "Finalized")
    }
}
```

- [ ] **Step 2: Run the test and verify failure**

Run on macOS after project generation:

```bash
xcodebuild test -project DetailHandoff.xcodeproj -scheme DetailHandoff -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -only-testing:DetailHandoffTests/JobStatusTests
```

Expected: FAIL because `JobStatus` does not exist.

- [ ] **Step 3: Implement the state machine**

Create `DetailHandoff/Domain/JobStatus.swift`:

```swift
import Foundation

enum JobStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case beforeCapture
    case awaitingAcknowledgment
    case inProgress
    case afterCapture
    case review
    case finalized
    case archived

    var id: String { rawValue }

    var next: JobStatus? {
        switch self {
        case .draft: .beforeCapture
        case .beforeCapture: .awaitingAcknowledgment
        case .awaitingAcknowledgment: .inProgress
        case .inProgress: .afterCapture
        case .afterCapture: .review
        case .review: .finalized
        case .finalized: .archived
        case .archived: nil
        }
    }

    func canTransition(to candidate: JobStatus) -> Bool {
        next == candidate
    }

    var displayName: String {
        switch self {
        case .draft: "Draft"
        case .beforeCapture: "Before photos"
        case .awaitingAcknowledgment: "Awaiting acknowledgment"
        case .inProgress: "In progress"
        case .afterCapture: "After photos"
        case .review: "Ready to review"
        case .finalized: "Finalized"
        case .archived: "Archived"
        }
    }
}
```

- [ ] **Step 4: Run the focused test**

Expected: all three `JobStatusTests` pass.

- [ ] **Step 5: Commit the state machine**

```bash
git add DetailHandoff/Domain/JobStatus.swift DetailHandoffTests/JobStatusTests.swift
git commit -m "feat: add job workflow state machine"
```

---

### Task 3: Add SwiftData Models and Repository

**Files:**
- Create: `DetailHandoff/Models/BusinessProfile.swift`
- Create: `DetailHandoff/Models/JobRecord.swift`
- Create: `DetailHandoff/Persistence/JobRepository.swift`
- Create: `DetailHandoffTests/JobRepositoryTests.swift`

**Interfaces:**
- Consumes: `JobStatus`
- Produces: `BusinessProfile`, `JobRecord`, `JobRepository.createJob(...)`, `JobRepository.advance(_:)`, `JobRepository.search(_:query:)`

- [ ] **Step 1: Write failing in-memory persistence tests**

Create `DetailHandoffTests/JobRepositoryTests.swift` with an in-memory `ModelContainer`. Test that `createJob` stores a draft with trimmed values, `advance` follows `JobStatus.next`, and `search` matches customer, vehicle label, or plate case-insensitively.

Use this setup in every test:

```swift
let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(
    for: BusinessProfile.self, JobRecord.self,
    configurations: configuration
)
let repository = JobRepository(context: container.mainContext)
```

The creation assertion uses:

```swift
let job = try repository.createJob(
    customerName: "  Marcus Lee  ",
    vehicleLabel: "2021 Honda Accord",
    plate: "7HKL248",
    color: "Pearl White",
    serviceName: "Full detail",
    notes: "Driveway gate code in message"
)
XCTAssertEqual(job.customerName, "Marcus Lee")
XCTAssertEqual(job.status, .draft)
XCTAssertNotNil(job.createdAt)
```

- [ ] **Step 2: Run tests and verify failure**

Expected: FAIL because models and repository do not exist.

- [ ] **Step 3: Implement `BusinessProfile`**

Create a SwiftData `@Model final class BusinessProfile` with `id`, `businessName`, `phone`, `email`, `disclaimer`, `createdAt`, and `updatedAt`. Default disclaimer:

```text
This report records visible vehicle condition and the services selected at the time shown. It is not insurance, a warranty, or a guarantee.
```

- [ ] **Step 4: Implement `JobRecord`**

Create a SwiftData `@Model final class JobRecord` with:

```swift
@Attribute(.unique) var id: UUID
var customerName: String
var vehicleLabel: String
var plate: String
var color: String
var serviceName: String
var notes: String
var statusRawValue: String
var createdAt: Date
var updatedAt: Date
var deletedAt: Date?
```

Expose `status` as a computed property backed by `statusRawValue`, defaulting safely to `.draft` if persisted data is unknown.

- [ ] **Step 5: Implement `JobRepository`**

Implement:

```swift
@MainActor
final class JobRepository {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func createJob(
        customerName: String,
        vehicleLabel: String,
        plate: String,
        color: String,
        serviceName: String,
        notes: String
    ) throws -> JobRecord

    func advance(_ job: JobRecord) throws

    func search(_ jobs: [JobRecord], query: String) -> [JobRecord]
}
```

`createJob` trims strings, inserts the model, and saves. `advance` rejects archived jobs with a typed `JobRepositoryError.noNextStatus`. `search` excludes records with `deletedAt != nil` and sorts newest first.

- [ ] **Step 6: Run repository and full unit tests**

Expected: all repository and state-machine tests pass.

- [ ] **Step 7: Commit persistence foundation**

```bash
git add DetailHandoff/Models DetailHandoff/Persistence DetailHandoffTests/JobRepositoryTests.swift
git commit -m "feat: persist local job records"
```

---

### Task 4: Add the App Shell, Theme, and First-Run Setup

**Files:**
- Modify: `DetailHandoff/App/DetailHandoffApp.swift`
- Create: `DetailHandoff/App/RootView.swift`
- Create: `DetailHandoff/DesignSystem/AppTheme.swift`
- Create: `DetailHandoff/Features/Onboarding/SetupView.swift`

**Interfaces:**
- Consumes: `BusinessProfile`, `JobRecord`
- Produces: app entry point, adaptive navigation, persisted first-run completion

- [ ] **Step 1: Write the app-container smoke test**

Add a test that creates an in-memory `ModelContainer` for both production models and inserts one `BusinessProfile`. Fetch it and assert the business name survives a save.

- [ ] **Step 2: Run the test and verify the initial failure**

Expected: FAIL until the shared schema and app container are defined.

- [ ] **Step 3: Implement the app entry point**

`DetailHandoffApp` creates a `ModelContainer` containing `BusinessProfile` and `JobRecord`, attaches it with `.modelContainer(container)`, and presents `RootView`.

- [ ] **Step 4: Implement the root navigation**

`RootView` queries `BusinessProfile`. If none exists, it presents `SetupView`; otherwise it shows a `TabView` with `JobsListView` and a Settings tab. The Settings tab initially displays the saved business identity and the statement `Records stay on this device.`

- [ ] **Step 5: Implement first-run setup**

`SetupView` requires a non-empty business name and accepts optional phone and email. Saving inserts one `BusinessProfile`; there is no login, network request, tracking permission, or paywall.

- [ ] **Step 6: Add reusable theme primitives**

Define `AppTheme` spacing constants `8`, `12`, `16`, `24`, and `32`, plus a `ReportCardModifier` using system background colors, a 16-point continuous corner radius, and a subtle separator stroke. Do not hard-code a competitor's layout, colors, icons, or copy.

- [ ] **Step 7: Build the app target**

Run the generic simulator build command from Task 1.

Expected: BUILD SUCCEEDED.

- [ ] **Step 8: Commit app shell**

```bash
git add DetailHandoff/App DetailHandoff/DesignSystem DetailHandoff/Features/Onboarding
git commit -m "feat: add local-first app shell and setup"
```

---

### Task 5: Implement Job Creation and Searchable Job List

**Files:**
- Create: `DetailHandoff/Features/Jobs/NewJobValidator.swift`
- Create: `DetailHandoff/Features/Jobs/NewJobView.swift`
- Create: `DetailHandoff/Features/Jobs/JobsListView.swift`
- Create: `DetailHandoffTests/NewJobValidatorTests.swift`

**Interfaces:**
- Consumes: `JobRepository.createJob`, `JobRepository.search`, `JobRecord`
- Produces: `NewJobValidator.validate(vehicleLabel:serviceName:)`, user-visible job creation and search

- [ ] **Step 1: Write failing form-validation tests**

Create tests asserting:

```swift
XCTAssertEqual(
    NewJobValidator.validate(vehicleLabel: "", serviceName: "Full detail"),
    .missingVehicle
)
XCTAssertEqual(
    NewJobValidator.validate(vehicleLabel: "2021 Honda Accord", serviceName: ""),
    .missingService
)
XCTAssertNil(
    NewJobValidator.validate(vehicleLabel: "2021 Honda Accord", serviceName: "Full detail")
)
```

- [ ] **Step 2: Run tests and verify failure**

Expected: FAIL because `NewJobValidator` does not exist.

- [ ] **Step 3: Implement validation**

Define equatable errors `missingVehicle` and `missingService`. Treat whitespace-only input as empty. Expose customer name, plate, color, and notes as optional form content.

- [ ] **Step 4: Implement `NewJobView`**

Use a grouped `Form` with Vehicle, Customer, Service, and Notes sections. The primary button is `Create job`; it validates, saves through `JobRepository`, dismisses on success, and shows a specific English validation or persistence message on failure.

- [ ] **Step 5: Implement `JobsListView`**

Use `@Query` to obtain `JobRecord` values, exclude recently deleted records, filter through `JobRepository.search`, and render:

- vehicle label as the primary line;
- customer name or `Customer not provided` as the secondary line;
- status label and creation date;
- an empty state explaining how the first report starts;
- toolbar button `New job`;
- `.searchable(text:prompt:)` with prompt `Customer, vehicle, or plate`.

Selecting a row opens `JobWorkflowView(job:)`.

- [ ] **Step 6: Run focused tests and build**

Expected: validator tests pass and generic simulator build succeeds.

- [ ] **Step 7: Commit the first working feature**

```bash
git add DetailHandoff/Features/Jobs DetailHandoffTests/NewJobValidatorTests.swift
git commit -m "feat: add local job creation and search"
```

---

### Task 6: Implement the Workflow Navigation Skeleton

**Files:**
- Create: `DetailHandoff/Features/Workflow/JobWorkflowView.swift`
- Create: `DetailHandoff/Features/Workflow/WorkflowStepContent.swift`
- Modify: `DetailHandoffTests/JobRepositoryTests.swift`

**Interfaces:**
- Consumes: `JobRecord.status`, `JobRepository.advance(_:)`
- Produces: visible progress, phase-specific instructions, guarded next-step transition

- [ ] **Step 1: Extend tests for guarded transitions**

Add tests proving a draft advances to `beforeCapture`, each advance updates `updatedAt`, and an archived record throws `JobRepositoryError.noNextStatus` without changing state.

- [ ] **Step 2: Run the focused tests and verify failure**

Expected: at least the timestamp or typed-error assertion fails before repository behavior is completed.

- [ ] **Step 3: Implement phase content**

`WorkflowStepContent` maps each status to concise English content:

- Draft: `Review the vehicle and service details.`
- Before photos: `Capture the vehicle before work begins.`
- Awaiting acknowledgment: `Review the visible condition with the customer.`
- In progress: `The service is underway.`
- After photos: `Capture the finished vehicle from the same positions.`
- Ready to review: `Check the record before creating the report.`
- Finalized: `This report version is sealed.`
- Archived: `This job is archived.`

- [ ] **Step 4: Implement `JobWorkflowView`**

Show vehicle, customer, service, current status, a progress indicator over the eight statuses, and the appropriate phase content. The primary button advances through the state machine and is hidden when archived. For Phase 1, transitions into capture, acknowledgment, and report phases display their approved instructions without pretending those later-phase capabilities are implemented.

- [ ] **Step 5: Run unit tests and build**

Expected: all tests pass and BUILD SUCCEEDED.

- [ ] **Step 6: Commit workflow skeleton**

```bash
git add DetailHandoff/Features/Workflow DetailHandoffTests/JobRepositoryTests.swift
git commit -m "feat: add end-to-end job workflow navigation"
```

---

### Task 7: Document and Verify the Phase 1 Deliverable

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-09-03-detailhandoff-phase-1-foundation.md`

**Interfaces:**
- Consumes: all Phase 1 tasks
- Produces: reproducible build instructions and recorded verification evidence

- [x] **Step 1: Update README build instructions**

Document these exact Mac steps:

```bash
brew install xcodegen
xcodegen generate
open DetailHandoff.xcodeproj
```

Also document the command-line generic simulator build and focused unit-test command. State that Windows can edit the repository but cannot run Xcode.

- [x] **Step 2: Run all verification commands fresh**

```bash
xcodegen generate
xcodebuild -project DetailHandoff.xcodeproj -scheme DetailHandoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild test -project DetailHandoff.xcodeproj -scheme DetailHandoff -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest'
git status --short
```

Expected:

- project generation exits 0;
- build reports `BUILD SUCCEEDED`;
- test reports `TEST SUCCEEDED` with zero failures;
- `git status --short` is empty after the final documentation commit.

Verification result on 2026-09-03 (Windows PowerShell, before the documentation
commit): `xcodegen generate`, the generic simulator `xcodebuild` build, and the
named iPhone 16 Pro `xcodebuild test` command each returned exit code 1 because
the macOS executable is not installed on Windows. No `BUILD SUCCEEDED` or
`TEST SUCCEEDED` result is claimed. The final post-commit `git status --short`
check is recorded in the Task 7 report.

- [x] **Step 3: Check privacy and scope mechanically**

Run:

```bash
rg -n 'URLSession|Firebase|RevenueCat|Analytics|StoreKit|Anthropic|SignInWithApple' DetailHandoff
```

Expected: no matches. Phase 1 must not contain networking, analytics, subscription, AI, or login code.

The command returned exit code 1 with no matches in `DetailHandoff`, consistent
with the Phase 1 scope. `git diff --check` also returned exit code 0.

- [x] **Step 4: Record platform-dependent gaps honestly**

If a named simulator is unavailable, list devices with `xcrun simctl list devices available`, choose an available iPhone on the latest installed iOS runtime, and record that exact destination in the commit message body. Do not claim TestFlight, camera, PDF, signature, backup, or real-device verification in Phase 1.

`xcrun simctl list devices available` was attempted and returned exit code 1
because `xcrun` is unavailable on Windows. Consequently no simulator inventory
or alternate destination exists to record, and no simulator, TestFlight,
camera, PDF, signature, backup, or real-device verification is claimed.

- [x] **Step 5: Commit documentation**

```bash
git add README.md docs/superpowers/plans/2026-09-03-detailhandoff-phase-1-foundation.md
git commit -m "docs: add Phase 1 build and verification guide"
```

The documentation is committed on `feature/phase-1-foundation`. The requested
push to `main` is intentionally pending: this task's preflight ruling prohibits
push/merge to `main`; the controller will perform the final branch workflow.

### Task 7 verification record

Fresh command evidence, static checks, self-review, and known gaps are recorded
in `.superpowers/sdd/2026-09-03-detailhandoff-phase-1-foundation/task-7-report.md`.

---

## Phase 1 Acceptance Checklist

- [ ] GitHub Actions generates the project and builds the iOS target (workflow present; macOS run not observed here).
- [x] Unit-test sources cover legal and illegal workflow transitions (execution pending on macOS).
- [x] SwiftData models and in-memory repository tests cover local business-profile and job persistence (execution pending on macOS).
- [x] First-run source creates a local business profile without login.
- [x] Source and tests cover draft-job creation and search.
- [x] Workflow source presents all eight statuses.
- [x] Privacy/scope scan found no networking, analytics, AI, subscription, or account integration symbols.
- [x] README explains Mac generation, build, and test commands.
- [ ] Push to `main` (pending controller finishing workflow; prohibited in this task).
