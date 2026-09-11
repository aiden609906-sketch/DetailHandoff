# Release Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development task-by-task.

**Goal:** Verify the integrated V1 code, export real simulator screenshots, and document the remaining external release gates without claiming publication.

**Architecture:** XCTest protects domain/persistence/file operations, XCUITest runs isolated deterministic fixtures on iPhone/iPad and captures actual rendered screens. CI retains test results and screenshots; release documentation maps every PRD requirement to implementation, tests and physical verification still required.

**Tech Stack:** XcodeGen, GitHub Actions macOS, XCTest/XCUITest, simulator screenshot/xcresult artifacts.

**Spec:** `docs/superpowers/specs/2026-09-03-detailhandoff-design.md`

## Global Constraints

- iOS/iPadOS 17+, English-first, local-only, USD 9.99 paid download with no in-app paywall.
- Test fixtures use isolated stores and generated sample assets, never user records. Fixture launch code is DEBUG-only.
- Do not publish, sign with unknown credentials, invent contact details, claim real-device checks, or claim App Review acceptance.

### Task 1: End-to-end UI verification and screenshot artifacts

**Files:** project.yml; `.github/workflows/ios-build.yml`; `DetailHandoffUITests/WorkflowUITests.swift`, `ScreenshotTests.swift`; focused accessibility identifiers in production views; `DetailHandoff/Testing/UITestFixtures.swift` behind DEBUG.

**Interfaces:** Launch arguments `--ui-testing` and `--screenshot-fixture` request isolated test state only in DEBUG. No test bypass is allowed in production transition validation. Generated image fixtures satisfy the same capture/import repository rules as production.

- [x] Tests first: clean launch setup → new job → search → workflow; complete fixture with valid capture and acknowledgment → draft PDF → seal → version/share UI; backup export/cancel; trash/restore; failing startup retry screen. Capture XCTAttachments for setup, list, new job, capture, findings, acknowledgment, report, settings, backup and trash.
- [x] Run XCUITest initially to record missing identifiers/flows (macOS CI). Implement identifiers and isolated fixture injection; never ship fabricated customer data as production records.
- [x] Add iPhone and iPad CI destinations chosen from available runtime inventories. Run UI tests and export PNG attachments from xcresult with supported Xcode tools; upload artifact paths and device/runtime names. If a screen cannot be automated, record exactly what failed and preserve the test failure rather than marking passed.
- [x] Inspect screenshots using available image tools; check narrow iPhone, iPad and accessibility text sizes for clipping, hidden actions and unreadable states. Fix each observed issue with a focused regression when possible.
- [x] Commit the UI verification and simulator screenshot work.

Evidence update, 2026-09-07:

- [x] UI fixtures/tests and iPhone/iPad attachment export ran at `d4f9556`; app build and 133 unit tests passed.
- [x] The 13 iPhone and 14 iPad PNGs were inspected and their runtime failures were retained as release blockers.
- [x] Evidence-based corrections were committed at `f2c5f2a` without bypassing production guards or system cancellation surfaces.
- [x] CI `34560087867`, attempt 2, built `9199120`, passed 149/0 unit tests and 9/0 UI tests on each selected iPhone and iPad simulator, and exported 30 attachments per device. Representative native-resolution report, Files exporter, and accessibility screenshots were inspected.

### Task 2: PRD traceability, privacy and release handoff

**Files:** README.md, `docs/release/acceptance.md`, `docs/release/privacy.md`, `docs/release/app-store.md`; update plan checklists based only on actual evidence.

- [x] Build a requirement matrix covering every PRD V1 item, linking its production files, test names, CI run and remaining manual checks. Missing required functionality is a code gap, not an external gate; return it to implementation before declaring code complete.
- [x] Record actual full-test counts/results, iPhone/iPad destinations, screenshots, and performance fixture results for a 40-photo PDF and backup roundtrip. Confirm migration from Phase 1 with a stored fixture without wiping prior records.
- [x] Privacy document describes real on-device data, permissions, user-initiated export and any system backup behavior accurately. App Store document records USD 9.99 paid download, no IAP, English-first copy, camera usage and required images; never assert the name is legally cleared or available without verification.
- [x] Explicit pending gates: developer membership/account/team/signing, real support email and policy URL, physical iPhone+iPad camera/permissions/interruption tests, TestFlight users, business agreements/tax/banking and App Review. Do not treat CI as a substitute for these.
- [x] Complete source review and green macOS CI; synchronize the documentation update to GitHub.

Evidence update, 2026-09-07:

- [x] The 17 V1 requirements, cross-cutting PRD sections, and 14 core acceptance criteria are mapped to source, tests, executed CI, and remaining checks in `docs/release/acceptance.md`.
- [x] Historical 40-photo PDF and backup-roundtrip functional evidence is recorded without moving the stable PDF samples.
- [x] CI `34560087867`, attempt 2, records 2.984 seconds and 2,486,430 bytes for the 40-photo PDF, 0.446 seconds for backup roundtrip, and 0.412 seconds for disk restore. These pass the documented deterministic-fixture guardrails; physical-device memory and real-photo performance remain open.
- [x] A real Phase 1 disk-store fixture test is committed at `4c76018` and checks all baseline fields without deleting the store before migration.
- [x] Privacy, paid-download/no-IAP, App Store metadata, and external release gates are documented without asserting unavailable credentials, URLs, devices, signing, TestFlight, or review.
- [x] Run the current 149-test unit target, including Phase 1 migration, logo atomicity, and final-review regressions, on macOS.
- [x] Complete source review, green current iPhone/iPad UI CI, representative screenshot inspection, and GitHub source synchronization. Physical and external release gates remain intentionally open in the handoff documents.

### Task 3: Compact UI automation reliability re-plan

**Trigger:** The first runtime UI correction task reached its 5/5 breaker. CI `34439586782` still has four compact-iPhone failures and one intermittent iPad screenshot-navigation failure, while build/unit tests remain green and a prior run proved iPad workflow 9/9.

**Files:** `DetailHandoffUITests/WorkflowUITests.swift`, `ScreenshotTests.swift`; focused production accessibility/navigation code only after a diagnostic run proves the failing boundary; `.github/workflows/ios-build.yml` only if targeted evidence export is required.

- [x] Evidence first: extract the complete action trace and hierarchy snapshot for each remaining failure. Record whether the intended control exists, which process/root owns it, whether it is visible/hittable, and what destination/system surface appears after the action. Do not change gestures or timeouts in this phase.
- [x] Compare each failing compact path with its passing iPad counterpart and with the last passing screenshot run. State one falsifiable root-cause hypothesis per failure group: report navigation, capture Skip confirmation, Files exporter cancellation, and fixture navigation readiness.
- [x] Add the smallest diagnostic or regression assertion needed to test each hypothesis. Prefer stable production semantics and condition-based readiness; do not add DEBUG shortcuts that bypass the production transition being verified.
- [x] Implement one root-cause fix at a time, preserving all nine UI methods, every downstream business assertion, the large-text edge checks, the proven iPad workflow paths, and the 20-minute per-device budget.
- [x] Require scoped review, a green 149-unit + iPhone 9/9 + iPad 9/9 macOS run, and visual inspection of replacement screenshots before marking release verification complete.

Completion evidence, 2026-09-11: CI `34560087867`, attempt 2, passed the full automated gate at commit `9199120`. The iPhone UI suite completed in about 621 seconds and the iPad suite in about 648 seconds, each within its 20-minute job budget. The first attempt's iPad Xcode launch timeout was environmental; rerunning the identical commit passed without a source change.
