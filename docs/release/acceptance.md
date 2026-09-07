# V1 acceptance and evidence

Last updated: 2026-09-07

## Release decision

**Not release-ready.** The most recent executable CI evidence (`33936741128`) built the app and passed 133 unit tests, but both UI destinations failed. Commit `f2c5f2a` contains focused corrections based on the captured hierarchies and screenshots; commit `4c76018` adds a real Phase 1 disk-store migration fixture. Follow-up run `34074499737` executed zero steps because GitHub Actions reported an account payment/spending-limit block. Consequently, the corrected UI behavior, the current 134-test unit target, the migration test, and final release screenshots are all pending.

Legend: **PASS** means the named behavior actually ran successfully in the cited run. **SOURCE** means implementation and tests exist but the current revision has not run successfully. **MANUAL** is an external or physical check that automation cannot establish.

## Evidence ledger

| Evidence | Commit | Result and scope |
|---|---|---|
| [CI 33848520274](https://github.com/aiden609906-sketch/DetailHandoff/actions/runs/33848520274) | `d6ebbf7` | **PASS:** app build and 77/0 unit tests. `testFortyPhotoPDFPaginatesAllEvidenceAndLongNotes` generated a 38-page signed report; the customer-unavailable fixture generated 4 pages. All 42 rendered pages were inspected with no observed clipping. The run did not record a release performance budget or duration. |
| [CI 33875097391](https://github.com/aiden609906-sketch/DetailHandoff/actions/runs/33875097391) | `b602c91` | **PASS:** app build and 118/0 unit tests, including `testRoundTripRestoresAllFieldsFrozenMediaAndCurrentSignature`. The run did not record a restore-duration budget. |
| [CI 33936741128](https://github.com/aiden609906-sketch/DetailHandoff/actions/runs/33936741128) | `d4f9556` | Mixed: app build **PASS** and 133/0 unit tests **PASS**. iPhone 17 Pro, iOS 26.5: 6 UI tests / 7 failures. iPad Pro 13-inch (M5), iOS 26.5: 6 UI tests / 5 failures. Attachments are diagnostic failure evidence, not accepted screenshots. |
| [CI 34074499737](https://github.com/aiden609906-sketch/DetailHandoff/actions/runs/34074499737) | `f2c5f2a` | **BLOCKED:** failed before any job step. GitHub reported failed recent account payments or an insufficient spending limit. No code or test conclusion can be drawn. |
| Migration fixture | `4c76018` | **SOURCE / pending CI:** `testPhase1DiskStoreMigratesWithoutWipingBaselineRecords` writes the exact Phase 1 `BusinessProfile` and `JobRecord` fields from `e09f85d` to disk, then opens the same file with the shipping models and checks both records and every baseline value. |

The stable 40-photo PDF outputs and rendered QA pages remain outside product source under `.superpowers/sdd/2026-09-04-reports/ci-33848520274/` and `.superpowers/sdd/2026-09-04-reports/pdf-qa/`. They must not be relocated into the app bundle or deleted during release preparation.

## PRD V1 requirement matrix

| # | PRD V1 requirement | Production implementation | Focused automated evidence | Current status / remaining check |
|---:|---|---|---|---|
| 1 | Company profile and report branding | `SetupView`, `SettingsView`, `BusinessProfile`, `BusinessConfiguration`, `BusinessRepository`, `ReportRenderer` | `BusinessRepositoryTests`; `ProjectSmokeTests.testBusinessProfileNameSurvivesSaveInSharedModelSchema`; report PDF tests | Unit **PASS** in 33936741128. Manually confirm imported logo, phone, email, and disclaimer on a physical-device PDF. |
| 2 | Service items and capture templates | `BusinessConfiguration`, `BusinessRepository`, `NewJobView`, `CaptureDocument` | `testConfigurationRequiresValidDefaultAndUniqueNonemptySlots`; `testSelectingDefaultServiceMovesItToTheNewJobDefaultPosition`; `CaptureDocumentTests` | Unit **PASS** in 33936741128. Physical UI edit/relaunch check pending. |
| 3 | Create, edit, search, delete jobs | `NewJobView`, `EditJobView`, `JobsListView`, `JobRepository`, `TrashService` | `JobDetailsTests`; `JobRepositoryTests`; `JobsListViewStateTests`; `WorkflowUITests.testCleanLaunchCreatesSearchableJobAndOpensWorkflow` | Unit **PASS**; UI failed in 33936741128. Corrected Form/keyboard and device-neutral search path at `f2c5f2a` awaits CI. Physical destructive-action confirmation pending. |
| 4 | Guided Before capture by vehicle position | `CaptureView`, `CameraPicker`, `CaptureDocument`, `CaptureRepository` | `CaptureDocumentTests`; `CaptureRepositoryTests`; complete/capture UI fixtures | Unit **PASS**. Simulator fixture UI failed before complete coverage; physical camera flow pending. |
| 5 | Required, supplementary, retake, and reasoned skip | `CaptureView`, `CaptureValidation`, `CaptureRepository` | `CaptureValidationTests`; `testRequiredSkipRejectsWhitespaceAndCanBeCleared`; repository add/remove tests | Unit **PASS**. Physical camera retake/import/skip presentation pending. |
| 6 | Manual findings and notes | `FindingsView`, `CaptureDocument`, `CaptureRepository` | `testFindingRequiresOwnedSlotPhotoAndBlocksLinkedPhotoDeletion`; capture corruption/reference tests | Unit **PASS**. Complete fixture and physical annotation UI pending. |
| 7 | Pre-service acknowledgment and on-screen signature | `AcknowledgmentView`, `SignaturePad`, `AcknowledgmentRecord`, `AcknowledgmentRepository` | `AcknowledgmentRepositoryTests`, including persisted signature and correct-job digest tests | Unit **PASS**. Physical signature ergonomics and interruption pending. |
| 8 | Customer unavailable state | `AcknowledgmentView`, `AcknowledgmentRepository`, `ReportRenderer` | `testMarkUnavailableRejectsBlankReason`; PDF unavailable fixture | Unit and 4-page rendered PDF **PASS** in historical evidence. Physical UI pending. |
| 9 | After capture at the same positions | `CaptureView`, `CaptureDocument`, `CaptureRepository` | `testRequiredSlotsNeedEvidenceOrMeaningfulSkipForEachPhase`; repository persistence tests | Unit **PASS**. Full physical Before-to-After camera path pending. |
| 10 | Translucent Before reference during After capture | `CaptureView`, `CapturePresentationState` | `testPhasePresentationRetainsPhotosAndSkipReasonTogether`; UI fixture source | Supporting state unit **PASS**. Visual overlay alignment must be checked on physical iPhone and iPad. |
| 11 | Before/After paired review | `PhotoPairView`, `CapturePresentationState`, `WorkflowStepContent` | `testPairsPhotosOnlyWithTheSameSlotAcrossPhases`; capture validation tests | Unit **PASS**. Physical paired-image readability pending. |
| 12 | Branded PDF preview, generate, seal, share | `ReportView`, `PDFPreview`, `ReportRenderer`, `ReportRepository`, `ShareSheet` | `ReportRepositoryTests`; `WorkflowUITests.testCompleteFixturePreviewsSealsAndCancelsRealShareSheet` | PDF generation and 40-photo QA **PASS** historically. UI failed in 33936741128; Draft Preview dismissal and system-share fixes await CI. Share cancellation still must actually run and retain history. |
| 13 | Immutable sealed-report versions | `ReportVersion`, `ReportSnapshot`, `ReportNumberLedger`, `ReportRepository`, `ReportPresentationPolicy` | sealing/revision/hash/ledger tests; `ReportPresentationPolicyTests`; revision UI test | Unit **PASS**. UI version descendant lookup fix awaits CI; physical preview/share of old and new versions pending. |
| 14 | Local job history and fast search | `JobsListView`, `JobRepository`, `ReportView` | search/date/sort tests; report history tests; clean and revision UI tests | Unit **PASS**. iPhone/iPad UI verification pending. Search performance with representative device data pending. |
| 15 | Full backup, restore, and single-job photo export | `BackupView`, `PhotoExportView`, `BackupService`, `BackupPackage`, `EvidencePackageDocument` | `BackupServiceTests`, especially roundtrip, disk restore, corruption/atomicity, and photo-export tests; backup UI test | Backup roundtrip **PASS** in 33875097391 and disk tests **PASS** in 33936741128. Real Files-provider detection/cancel fix awaits CI; physical Files/iCloud/external-volume roundtrip pending. |
| 16 | 30-day Recently Deleted | `RecentlyDeletedView`, `TrashService` | `TrashServiceTests`, especially 29-day/exactly-30-day, restore, purge, and rollback tests; trash UI flow | Unit **PASS**. iPhone/iPad restore UI and date-boundary device check pending. |
| 17 | Local storage use and safe cleanup | `StorageView`, `TrashService`, `MediaStore` | storage counting/confirmed cleanup/failure/retry/ownership tests in `TrashServiceTests` | Unit **PASS**. Physical low-storage warning, cleanup confirmation, and post-cleanup report access pending. |

## Cross-cutting PRD coverage

| PRD area | Evidence | Status / remaining check |
|---|---|---|
| Product principles and business model | Local repositories/files; no runtime networking, analytics, account, AI, ads, or StoreKit code found by static scan; product copy says USD 9.99 paid download with no IAP | **SOURCE.** App Store Connect configuration and instrumented network observation remain manual. |
| First-use flow | `SetupView`, `BusinessRepositoryTests`, clean-launch UI test | Unit **PASS**; UI failed and awaits corrected iPhone/iPad CI. Logo import and first-use data explanation require physical review. |
| Full order flow and eight statuses | `JobWorkflowView`, `JobStatus`, `JobRepositoryTests`, complete/revision fixtures | State transition unit tests **PASS**. No green end-to-end UI or offline physical run yet. |
| Information architecture and required fields | Setup, Jobs, New Job, Capture, Findings, Acknowledgment, Report, Settings views; validation/repository tests | Unit **PASS** for data/validation. Device-neutral navigation corrections await UI CI and physical review. |
| PDF required content, `DH-YYYYMMDD-XXXX`, SHA-256, and immutable revisions | `ReportRenderer`, `ReportRepository`, `ReportSnapshot`, `ReportVersion`, `ReportNumberLedger`; report test suite | Unit **PASS** and 40-photo PDFs visually inspected. Physical share/print/viewer compatibility pending. |
| Local storage, resizing, backup, and deletion rules | SwiftData models, `MediaStore`, `BackupService`, `TrashService`; media/backup/trash tests | Unit **PASS**. Phase 1 on-disk migration test exists but has not run; physical storage pressure and external Files destinations pending. |
| Exception handling | Camera/photo-import cancellation, storage decisions, invalid/missing media, acknowledgment guards, PDF failure, restore validation/rollback, startup retry, export/share cancellation, and revision guards have focused source/tests | Unit branches **PASS** where present. Startup and system-surface UI failed or were not reached; permission denial, process interruption, and low storage require physical checks. |
| Platform, accessibility, and Apple frameworks | SwiftUI/SwiftData/AVFoundation/PhotosUI/PDFKit/UIKit/CryptoKit/UniformTypeIdentifiers; iOS 17+ and device families 1,2 | Accessibility failure was observed. Responsive action-label and test-isolation fixes await CI; VoiceOver, Reduce Motion, rotation, split view, and Dynamic Type require device review. |
| Privacy and security | See `privacy.md`; private app storage and user-initiated exports; no developer server | Static source evidence only. Verify data protection/system-backup behavior and observe network traffic on physical devices before release. |
| V1 exclusions and later candidates | No servers, login, cloud sync, AI analysis, booking, payments, CRM, multi-user portal, Android, or legal-effect promise | Correctly outside V1 acceptance. Future-candidate items must not be represented as current features. |

## Core acceptance criteria

| PRD criterion | Actual evidence | Decision |
|---|---|---|
| Complete a job and generate PDF in airplane mode | No successful offline end-to-end device run | **MANUAL pending** |
| Auto-save every photo and field edit | Fresh-context persistence tests for jobs, captures, acknowledgment, reports | **Unit PASS**; force-quit physical check pending |
| Preserve progress after forced quit/relaunch | Fresh-context tests | **Unit PASS**; physical termination/relaunch pending |
| Never pair the wrong Before/After image | `testPairsPhotosOnlyWithTheSameSlotAcrossPhases` | **Unit PASS** |
| Block sealing when required evidence is missing without a skip reason | capture validation and `testSealRejectsInvalidAcknowledgmentAndIncompleteCaptureWithoutMutation` | **Unit PASS** |
| Bind signature to the correct job and time/content | acknowledgment digest/currentness tests | **Unit PASS** |
| Include customer-unavailable state in the report | unavailable repository test and 4-page rendered PDF | **PASS** |
| Reliably generate about 40 photos | 38-page signed PDF in 33848520274 | **PASS** for simulator fixture; physical performance pending |
| Include business, vehicle, service, photos, findings, acknowledgment, disclaimer | report snapshot/repository tests and rendered PDF inspection | **PASS** for fixtures; business-owner content review pending |
| New version after editing; old version unchanged | sealing/revision/frozen-file tests | **Unit PASS**; UI and physical sharing pending |
| Restore full backup after clearing test data | backup roundtrip and disk-store replacement tests | **Unit PASS** in historical/current executed suites; physical destination roundtrip pending |
| Restore a recently deleted job within 30 days | trash tests | **Unit PASS**; UI failed/pending |
| No degraded core behavior with network disabled | No green offline UI run | **MANUAL pending** |
| No business data sent to a developer server | Static scan found no networking/developer backend | **SOURCE only**; instrumented physical network observation pending |

## UI screenshots and current failures

Run `33936741128` retained 13 iPhone PNGs and 14 iPad PNGs under `.superpowers/sdd/2026-09-04-release-verification/ci-33936741128/`. They cover portions of setup, jobs, new job, workflow, reports, Settings, and accessibility states. Inspection found accessibility-size leakage across iPhone tests, clipped accessibility action content, keyboard/Form reachability problems, iPad Settings/search query assumptions, missing Draft Preview dismissal, and undetected real Files-provider hierarchy. These images are diagnostic artifacts only.

A release candidate still needs a successful run that exports and visually inspects setup, list, new job, capture, findings, acknowledgment, report, Draft Preview, sealed version/history, real share cancellation, Settings, backup/Files cancellation, trash/restore, startup retry, and accessibility views on both selected device classes. No screenshot may be marked accepted merely because an attachment exists.

## Pending release gates

- Resolve GitHub Actions billing/spending limits; run the current revision on macOS. Require app build, all 134 current unit tests including Phase 1 disk migration, all 6 UI tests on both iPhone and iPad, exported PNGs, and visual inspection.
- Run physical iPhone and iPad tests for camera capture, photo permission states, cancellation, force-quit/interruption, airplane mode, rotation/multitasking, large Dynamic Type/VoiceOver, low storage, 40-photo performance, PDF viewers/share destinations, Files/iCloud/external backup restore, deletion, and cleanup.
- Establish Apple Developer membership, account owner, team, bundle identifier, certificates, profiles, signing, and release archive validation.
- Verify product-name and trademark clearance. No clearance or App Store availability is claimed.
- Supply and verify a real support contact and public privacy-policy URL.
- Complete App Store metadata, compliant screenshots, 1024px icon artwork, age rating, category, export-compliance answers, reviewer notes, and localization review.
- Recruit TestFlight users and complete feedback/remediation; no TestFlight distribution has occurred.
- Complete Apple business agreements, tax, banking, pricing/territory configuration, and App Review. No submission, approval, or publication is claimed.

## Exit criteria

Only change the release decision after all code-required checks are green and the applicable external gates are evidenced. CI is not a substitute for physical camera, permission, interruption, accessibility, Files-provider, signing, TestFlight, business, or App Review checks.
