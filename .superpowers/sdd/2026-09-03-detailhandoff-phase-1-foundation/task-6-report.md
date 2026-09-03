# Task 6 Report: Workflow Navigation Skeleton

## Implementation

- Expanded `JobWorkflowView` from Task 5's read-only handoff destination into the Phase 1 workflow screen.
- The view shows vehicle, customer, service, current status, an eight-status progress indicator, and a repository-backed primary transition button. The button is not rendered for archived jobs.
- Added `WorkflowStepContent`, whose one status switch supplies the exact approved English instruction for each of the eight states. It adds no photo, signature, report, or PDF capability.
- `JobRepository.advance(_:)` now sets `updatedAt` immediately before saving, while retaining and using Task 5's `saveChanges` injection seam.

## Tests

- `testAdvanceMovesDraftToBeforeCaptureAndUpdatesTimestamp` proves the initial state transition and timestamp refresh.
- `testAdvanceUpdatesTimestampForEveryTransition` exercises all seven permitted transitions. Before every advance it assigns `updatedAt` the deterministic date `1970-01-01`, then verifies a later value.
- `testAdvanceRejectsArchivedJobWithNoNextStatusError` asserts the typed error and verifies both archived status and its fixed historical `updatedAt` remain unchanged.

## RED / GREEN Evidence

The transition tests were added before the repository production change. Against the pre-change implementation, their timestamp assertion would fail because `advance(_:)` updated only `status` and called `context.save()`.

The required red focused XCTest command was attempted before the production change, but this Windows host cannot start it because `xcodebuild` is not installed. The same focused test command was attempted after the production change (GREEN attempt) and was blocked by the identical platform limitation. This host therefore cannot truthfully report an observed XCTest RED or GREEN result.

## Commands and Output

```powershell
xcodebuild test -scheme DetailHandoff -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DetailHandoffTests/JobRepositoryTests
```

Before and after the code change, PowerShell returned exit code 1: `The term 'xcodebuild' is not recognized`.

```powershell
xcodebuild build -scheme DetailHandoff -destination 'generic/platform=iOS'
```

PowerShell returned exit code 1 for the same missing `xcodebuild` executable. `swift` and `swiftc` are also unavailable, so no local Swift parse or typecheck can run.

```powershell
git diff --check
```

Result: exit code 0 with no whitespace errors. Git emitted only line-ending conversion warnings for existing tracked Swift files.

Static checks confirmed the repository timestamp assignment, the archived button guard, and the first/last exact phase instructions. These checks are not substitutes for XCTest or an iOS build.

## Files

- Modified: `DetailHandoff/Persistence/JobRepository.swift`
- Modified: `DetailHandoff/Features/Workflow/JobWorkflowView.swift`
- Added: `DetailHandoff/Features/Workflow/WorkflowStepContent.swift`
- Modified: `DetailHandoffTests/JobRepositoryTests.swift`

## Self-Review

- The view advances only through `JobRepository.advance(_:)`; it introduces no parallel state mutation path.
- The repository's `next` guard still executes before changing either status or timestamp, so archived jobs preserve state and throw `JobRepositoryError.noNextStatus`.
- Every status has one exact approved instruction, including the terminal archived message.
- The UI hides the only primary advance action when archived and remains a navigation skeleton only for future capture, acknowledgment, and report phases.
- The Task 5 `saveChanges` initializer remains intact and is now also honored by `advance(_:)`.

## Concerns / Follow-up

Run `xcodebuild test` and the iOS build on macOS with Xcode before asserting test/build success or merging. This Windows host cannot compile SwiftUI/SwiftData sources or execute XCTest. The explicit handoff instruction also prohibits a subagent review, so the review here is self-review plus static inspection.

## Fix Round 1

### Root Cause and Fix

`JobRepository.advance(_:)` updated the in-memory `status` and `updatedAt` before calling the injected `saveChanges` seam. When that closure threw, the method rethrew without restoring either property, leaving the displayed job advanced even though persistence failed.

`advance(_:)` now snapshots the validated current status and timestamp before mutation. Its save-error `catch` restores both fields and rethrows the original error. Successful advance behavior and the existing archived guard are unchanged.

### Regression Test

Added `testAdvanceRestoresStatusAndTimestampWhenSaveFails` in `DetailHandoffTests/JobRepositoryTests.swift`. It creates a real draft in an in-memory `ModelContext`, fixes its timestamp to `1970-01-01`, then advances through a `JobRepository` whose existing injected save seam throws `SaveFailure.simulated`. It asserts that the call throws, the status remains `.draft`, and the timestamp remains the exact fixed value.

The test was added before the rollback code. It would fail against the prior `advance(_:)` implementation because that implementation left the job at `.beforeCapture` with a new current timestamp after the controlled save failure.

### Commands and Output

```powershell
xcodebuild test -scheme DetailHandoff -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DetailHandoffTests/JobRepositoryTests/testAdvanceRestoresStatusAndTimestampWhenSaveFails
```

RED and GREEN attempts both returned PowerShell exit code 1 before XCTest could start: `The term 'xcodebuild' is not recognized as a name of a cmdlet, function, script file, or executable program.` This Windows host cannot observe XCTest execution.

```powershell
git diff --check
```

Result: no whitespace errors; Git emitted only line-ending conversion warnings for the modified tracked Swift files.

Static checks confirmed the regression test name plus the status and timestamp snapshot/restore lines in `JobRepository.advance(_:)`.

### Self-Review

- The rollback captures both mutable values only after the `next` guard succeeds, so archived records still fail without any mutation.
- The error is rethrown after restoration, allowing the view to continue showing its save-failure alert without displaying a falsely advanced workflow state.
- The regression exercises the real job model and in-memory context; the narrow injected closure represents only the otherwise nondeterministic save failure boundary.
