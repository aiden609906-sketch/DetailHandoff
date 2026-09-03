# Task 5 Report: Job Creation and Searchable Job List

## Implementation

- Replaced `RootView`'s private temporary `JobsListView` placeholder with the production `JobsListView`.
- Added `NewJobValidator` with whitespace-aware required vehicle and service validation. Its equatable errors are `missingVehicle` and `missingService`.
- Added `NewJobView`, a grouped form with Vehicle, Customer, Service, and Notes sections. Customer name, plate, color, and notes are optional. `Create job` validates before calling `JobRepository.createJob` with the environment `ModelContext`, dismisses after a successful save, and displays English validation or persistence errors.
- Added `JobsListView`, using `@Query` and `JobRepository.search`. It omits soft-deleted records, supports the required searchable prompt, supplies a first-report empty state, and opens the workflow destination from each job row.
- Added the preflight-required minimal `Features/Workflow/JobWorkflowView.swift`. It is intentionally read-only and displays only job identity, service, and status; it neither advances state nor exposes capture/report actions. Task 6 should replace or expand it.

## Files

- Modified: `DetailHandoff/App/RootView.swift`
- Added: `DetailHandoff/Features/Jobs/NewJobValidator.swift`
- Added: `DetailHandoff/Features/Jobs/NewJobView.swift`
- Added: `DetailHandoff/Features/Jobs/JobsListView.swift`
- Added: `DetailHandoff/Features/Workflow/JobWorkflowView.swift`
- Added: `DetailHandoffTests/NewJobValidatorTests.swift`

## TDD Evidence

`DetailHandoffTests/NewJobValidatorTests.swift` was created before `NewJobValidator.swift`. The tests cover empty vehicle, whitespace-only vehicle, empty service, whitespace-only service, and the valid vehicle/service pair. Each test exercises the real validator and would fail if the corresponding required-input branch were removed.

The required red-phase focused test command was attempted immediately after adding the tests:

```powershell
xcodebuild test -project DetailHandoff.xcodeproj -scheme DetailHandoff -only-testing:DetailHandoffTests/NewJobValidatorTests
```

It could not start because Windows does not provide `xcodebuild` (`The term 'xcodebuild' is not recognized`). Therefore this host could not observe the expected missing-symbol compilation failure. The same focused test command was attempted again after implementation, with the same host-tool limitation.

## Verification Commands and Results

```powershell
xcodebuild test -project DetailHandoff.xcodeproj -scheme DetailHandoff -only-testing:DetailHandoffTests/NewJobValidatorTests
```

Result: not executable on this Windows host because `xcodebuild` is unavailable.

```powershell
xcodebuild build -project DetailHandoff.xcodeproj -scheme DetailHandoff -destination 'generic/platform=iOS Simulator'
```

Result: not executable on this Windows host because `xcodebuild` is unavailable.

```powershell
git diff --check
```

Result: exit code 0; no whitespace errors. Git emitted only its existing line-ending conversion warning for `DetailHandoff/App/RootView.swift`.

## Self-Review

- The UI uses the existing `JobRepository` and the SwiftUI-provided `ModelContext`; it does not create a parallel persistence path.
- Search and empty states exclude deleted records, while `JobRepository.search` remains the sole text-match and date-sort implementation.
- All required labels and search prompt are present, including `Create job`, `New job`, `Customer not provided`, and `Customer, vehicle, or plate`.
- Persistence failure is surfaced as: `We couldn't save this job. Please try again.`
- No workflow-state mutation, photo capture, acknowledgment, or report controls were added to the temporary handoff destination.

## Limitation / Follow-up

Run the focused validator suite and generic iOS Simulator build on macOS with Xcode (and generate the Xcode project from `project.yml` if it is not already generated) before release or merge confidence is claimed. This environment cannot compile SwiftUI/SwiftData iOS sources.
