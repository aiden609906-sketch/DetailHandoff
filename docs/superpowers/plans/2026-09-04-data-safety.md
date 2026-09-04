# Data Safety and Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development task-by-task.

**Goal:** Complete editable business/templates/jobs, safe backups, photo exports, 30-day trash and local-storage management.

**Architecture:** Export versioned Codable DTOs rather than copying a live SQLite file. Use a Files document package with a manifest and checksummed assets; validate fully before transactional replacement of database records. Media lives in unique namespaces so failed restore never replaces existing assets. A dedicated deletion service tracks soft deletion and purges only assets unreferenced by every live or retained report.

**Tech Stack:** SwiftUI FileDocument/FileWrapper, SwiftData, Foundation, CryptoKit, PhotosUI, XCTest; iOS/iPadOS 17+.

**Spec:** `docs/superpowers/specs/2026-09-03-detailhandoff-design.md`

## Global Constraints

- Existing approved local-only USD 9.99 model; no network, third-party SDK, login, subscription or AI.
- Never overwrite current data until the complete backup and all asset checksums/paths/references/schema versions are validated.
- Restore failure leaves old data intact; permanent deletion requires an explicit user confirmation. Exactly 30 days is the retention boundary.
- Archived/finalized business records do not become editable through general job forms; explicit report revisions preserve frozen history.
- Company/template edits affect new jobs and future snapshots, never reinterpret old photos or sealed reports.

## File map

Domain: `BusinessConfiguration.swift`, `BackupManifest.swift`, `BackupDTO.swift`.
Persistence: `BusinessRepository.swift`, `BackupService.swift`, `TrashService.swift`.
Features/Settings: `SettingsView.swift`, `BusinessSettingsView.swift`, `TemplateSettingsView.swift`, `BackupView.swift`, `StorageView.swift`, `RecentlyDeletedView.swift`.
Features/Jobs: `EditJobView.swift`; existing NewJobView/JobsListView/RootView become consumers.
Tests: BusinessRepositoryTests, JobEditingTests, BackupServiceTests, TrashServiceTests.

### Task 1: Business branding, templates and durable job editing

**Files:** BusinessConfiguration/BusinessRepository, settings views, EditJobView, existing models/new-job/root/list/workflow and tests.

**Interfaces:**

```swift
struct ServiceOption: Codable, Equatable, Identifiable { var id: UUID; var name: String }
struct CaptureTemplateOption: Codable, Equatable, Identifiable {
    var id: UUID; var name: String; var slots: [CaptureSlot]
}
struct BusinessConfiguration: Codable, Equatable {
    var services: [ServiceOption]
    var templates: [CaptureTemplateOption]
    var defaultTemplateID: UUID
}
// BusinessProfile adds optional configurationData and uses logoImagePath.
// JobRecord adds customerPhone/customerEmail/location optional Strings.
// BusinessRepository saves business details/configuration/logo with rollback.
// JobRepository.updateDetails(...) validates and saves editable fields.
// EditJobView(job: JobRecord), SettingsView(), RecentlyDeletedView().
```

- [ ] Write tests first: nonempty business identity, one-profile invariant, valid default template, nonempty unique slot IDs, new jobs snapshot templates, edited global templates do not affect existing jobs, field save persists through fresh context, save failures restore fields, finalized edit rejects, date query matches local YYYY-MM-DD.
- [ ] Attempt focused XCTest and document result.
- [ ] Add profile/config editors with nonempty service/template validation, add/edit/reorder/remove options and clear warnings on deleting used defaults. Use a stable Standard Detail default matching capture plan. Logo import compresses privately through media storage; optional absence is valid. Setup displays the default disclaimer and local-data-loss warning and gives access to default service/template selection before first job.
- [ ] NewJobView selects one or more saved services and a template, stores the template snapshot at creation; allow service text fallback for upgraded jobs. Add optional customer phone/email/location. EditJobView saves each field on change using a debounced or serialized explicit repository save with visible failed-save/retry state; do not falsely show saved when an error occurs. Pre-service edits make acknowledgment stale via its fingerprint. Add date search to repository without breaking customer/vehicle/plate search.
- [ ] Settings hosts branding, templates, disclaimer, privacy/version and data-safety destinations as those are introduced; do not leave inert controls. No fabricated support address: show support setup in release checklist until a real contact is supplied.
- [ ] Run CI; commit `feat: manage branding templates and editable job details`.

### Task 2: Checksummed backup, transactional restore and photo export

**Files:** BackupManifest/BackupDTO, BackupService, BackupView and tests; root/settings integration.

**Interfaces:**

```swift
struct BackupAsset: Codable, Equatable {
    var relativePath: String; var byteCount: Int; var sha256: String
}
// BackupManifest schemaVersion = 1, createdAt, DTO profile/jobs, assets.
// BackupService(context: ModelContext, media: MediaStore)
// makeBackup() throws -> FileWrapper
// validate(_ package: FileWrapper) throws -> ValidatedBackup
// restore(_ validated: ValidatedBackup) throws
// exportPhotos(for job: JobRecord) throws -> FileWrapper
```

- [ ] Tests first: round trip includes all editable fields, capture docs, signature strokes, report snapshots/PDFs and soft-deleted jobs. Reject traversal/absolute/symlink paths, missing/extra asset references, checksum mismatch, wrong sizes, duplicate IDs, unsupported versions and conflicting report IDs before mutation. Inject restore save failure and prove old records/assets unchanged. Successful fresh-context reload must match original fixture. Export manifest identifies Before/After/slot/date and includes full photos.
- [ ] Attempt focused tests, then implement.
- [ ] Use FileWrapper directory package with JSON manifest and regular-file assets, exposed through custom UTType and FileDocument. Stage imported media under a fresh namespace, remap paths consistently across live capture, logo and frozen report snapshots, preserve original report bytes/digests. Validate required images/PDFs and relationships before deleting/inserting database records. Commit replacement through one isolated ModelContext transaction; on failure rollback and delete only staged assets. Do not overwrite active root assets. On success notify/reload the UI so stale object references are not reused. Confirm replacement before restore; security-scoped Files access must be closed on all paths.
- [ ] Export/share via Files/system sheet only on user action; cancellation changes nothing. Show clear complete/failed result; no silent partial restore. Keep database/live WAL out of backups.
- [ ] Full CI; commit `feat: back up restore and export local evidence safely`.

### Task 3: Recently deleted and storage lifecycle

**Files:** TrashService, StorageView, RecentlyDeletedView, JobsListView swipe actions and tests.

**Interfaces:** `TrashService(context: ModelContext, media: MediaStore, now: () -> Date)` with `softDelete(_:)`, `restore(_:)`, `purgeExpired()`, `permanentlyDelete(_:)`, `storageSummary()`; throwing operations.

- [ ] Tests first: 29 days recoverable, exactly 30 days expired, boundary clock injected; shared asset references preserved; report version files removed only when owning deleted job is purged and no other record references them; failed DB save leaves metadata/assets; path protection applies to imported records too.
- [ ] Attempt focused tests; implement soft delete as saved deletedAt with rollback. Active queries exclude deleted jobs. Restore before expiry clears deletedAt; after expiry show expired state. Permanent deletion is gated by UI confirmation containing job identity, then save metadata removal before physical cleanup. Cleanup failures remain visible/retryable, not data-corrupting; never delete outside private media root.
- [ ] Settings shows bytes used and per-job storage, export/backup before cleanup guidance and Recently deleted. Run retention purge at a safe startup/foreground point; serialise against imports/restores and do not automatically wipe unreadable assets. A full backup includes retained trash until expiry.
- [ ] Full CI; commit `feat: add recoverable deletion and storage management`.

## Acceptance boundary

After these tasks, all required functional subsystems must be connected to usable screens. UI automation, privacy/release materials, screenshot artifacts, physical devices, paid developer membership and App Review remain the following release plan. No store publication happens in this plan.
