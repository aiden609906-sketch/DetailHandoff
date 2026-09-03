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

## Fix Round 1

### Changes

- Added `JobsListContentState` in `DetailHandoff/Features/Jobs/JobsListView.swift`. It now distinguishes a first-job empty list from a non-empty local list whose current search has no matches. The view presents `No matching jobs` with a query-refinement message in the latter case.
- `JobRepository.createJob` now deletes the newly inserted `JobRecord` before rethrowing any save error. This keeps the failed create from remaining in the calling `ModelContext` and appearing as a pending job on a later query/save.
- Added an internal `saveChanges` initializer seam solely to make the existing repository's save-error boundary deterministic in a unit test. The production initializer continues to call `ModelContext.save()` unchanged.

### Covering Tests

- `DetailHandoffTests/JobsListViewStateTests.swift`
  - `testContentStateShowsFirstJobMessageWhenThereAreNoActiveJobs`
  - `testContentStateShowsNoResultsWhenActiveJobsDoNotMatchSearch`
  - `testContentStateShowsJobsWhenSearchReturnsMatches`
- `DetailHandoffTests/JobRepositoryTests.swift`
  - `testCreateJobRemovesPendingJobWhenSaveFails`

The repository test uses a real in-memory `ModelContext` and verifies its fetch has no `JobRecord` after a controlled save error. It does not mock persistence queries or model insertion; the narrowly injected operation is the otherwise nondeterministic failing save itself.

### TDD Evidence

The list-content state tests and the failed-save cleanup test were added before `JobsListContentState`, the repository save seam, or the cleanup catch branch. Their production changes would respectively fail the tests if the no-match case returned the first-job state, or if the catch no longer removed the pending object.

The red and green focused commands were both attempted:

```powershell
xcodebuild test -project DetailHandoff.xcodeproj -scheme DetailHandoff -only-testing:DetailHandoffTests/JobsListViewStateTests -only-testing:DetailHandoffTests/JobRepositoryTests/testCreateJobRemovesPendingJobWhenSaveFails
```

Output on both attempts: `xcodebuild` is not recognized as a PowerShell command. Windows therefore prevented observing either the expected missing-symbol red compilation failure or XCTest green run.

### Verification Commands and Results

```powershell
xcodebuild test -project DetailHandoff.xcodeproj -scheme DetailHandoff -only-testing:DetailHandoffTests/JobsListViewStateTests -only-testing:DetailHandoffTests/JobRepositoryTests/testCreateJobRemovesPendingJobWhenSaveFails
```

Result: not executable because this Windows host has no `xcodebuild`.

```powershell
xcodebuild build -project DetailHandoff.xcodeproj -scheme DetailHandoff -destination 'generic/platform=iOS Simulator'
```

Result: not executable because this Windows host has no `xcodebuild`.

```powershell
git diff --check
```

Result: executed after the code changes with exit code 0; no whitespace errors. Git emitted only line-ending conversion warnings.

### Self-Review

- The first-job onboarding copy is now shown only when the active (non-deleted) job count is zero.
- Existing jobs with zero matches cannot receive the first-report guidance.
- Cleanup scopes only the newly created job; it does not roll back unrelated unsaved work in the shared model context.
- The original `JobRepository(context:)` initializer and all successful-create behavior are preserved.
