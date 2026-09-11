# Privacy and local data behavior

Last updated: 2026-09-11

This document describes the current V1 source. It is an engineering handoff, not a published privacy policy or legal determination.

## Data stored by the app

DetailHandoff stores business profile and branding settings; service and capture-template configuration; customer names and optional contact details; vehicle, plate, color, service, location, and notes; workflow state and timestamps; Before/After capture metadata; user-selected or camera-created photos and thumbnails; findings; customer name, signature strokes, or an unavailable reason; generated PDF versions, hashes, and report-number ledger; backup manifests; and deletion/storage metadata.

Structured records, including signature strokes and report-snapshot metadata, use SwiftData. Original evidence images, thumbnails, business logos, and generated PDFs use files in the app's local container. User-created export and backup packages are written to the destination the user selects. Evidence images are resized for app storage and the app does not intentionally save captured or imported evidence back to the user's Photos library.

Deleted jobs remain recoverable in Recently Deleted for up to 30 days unless the user restores or permanently removes them. Cleanup protects files still referenced by active, deleted, or frozen report history according to repository ownership checks.

## Permissions

| Capability | Current purpose |
|---|---|
| Camera | “DetailHandoff uses the camera to document vehicle condition before and after service.” The system asks when the user invokes camera capture. |
| Photo selection | “DetailHandoff lets you import vehicle photos selected by you.” is currently declared, while the app uses SwiftUI `PhotosPicker` for user-selected images and does not request broad photo-library authorization. Release QA must verify that no unnecessary library permission prompt appears. |

The current source does not request microphone, location, contacts, Bluetooth, advertising tracking, or notification permission. Permission denial and later recovery still require physical-device verification before release.

## Required Reason API declaration

The capacity check uses `volumeAvailableCapacityForImportantUsageKey` before capture/import can write media. `DetailHandoff/PrivacyInfo.xcprivacy` declares `NSPrivacyAccessedAPICategoryDiskSpace` with reason `E174.1` for this user-visible storage check. It declares tracking false, no tracking domains, and no collected data types, consistent with the local-only implementation. `project.yml` explicitly includes this file in the application resource build phase.

Windows checks parsed the plist and project resource entry semantically. The XCTest `testBundledPrivacyManifestDeclaresDiskSpacePurposeWithoutTrackingOrCollection` also passed against the built app resource in CI `34560087867`, attempt 2. This does not establish signed-archive compliance or App Review acceptance; signed-archive validation remains a release gate.

## Network, accounts, and tracking

The current source contains no developer-operated server integration, account/login flow, analytics SDK, advertising SDK, CloudKit sync, subscription, in-app purchase, or third-party runtime SDK. A static scan found no URLSession-based business-data transport. This is source evidence, not a packet-level guarantee; the release checklist requires an instrumented physical-device network observation with core workflows exercised offline.

Apple's operating system, App Store, system share destinations, Files providers, and device-backup services operate under their own settings and terms. This app cannot describe those providers as if they were DetailHandoff servers.

## When data leaves the app

App-initiated data handoff occurs only after a user invokes an export or operating-system surface:

- PDF sharing can hand a selected report version to the system share sheet and a destination the user chooses.
- Single-job photo export writes an evidence package through the system document/Files interface.
- Full backup writes a backup package through the system document/Files interface; restore reads a package the user selects and validates it before replacing app data.

Canceling share or export leaves the tested fixture's job and report history unchanged in the iPhone and iPad simulator flows from CI `34560087867`, attempt 2. Physical-provider checks are still required. Once a file is handed to Files, iCloud Drive, an external volume, email, messaging, or another share extension, that destination controls its copies and retention.

## System backup behavior

The app contains no automatic CloudKit/iCloud database sync and does not initiate remote backup. However, the source does not mark its entire container as excluded from operating-system device backups. Depending on the user's iCloud Backup or computer-backup configuration and Apple's platform behavior, system-level backups may include app data. The app does not control, inspect, or promise exclusion from those backups.

The user-created DetailHandoff backup package is separate from system device backup. It is not described as encrypted by the app; protection in transit or at the chosen destination depends on the destination and device configuration.

## Retention, deletion, and loss

- Active records remain until the user deletes them.
- Deleted jobs are retained for the 30-day recovery window unless permanently removed; expiry/cleanup rules then reclaim owned files when safe.
- A user-created backup or exported PDF/photo package is not deleted when its app record is deleted; the user must manage copies at their destination.
- Uninstalling the app, erasing or losing a device, or corrupting local storage may permanently lose app data unless a usable app backup or system device backup exists.
- Restore validation is designed to reject corrupt, incomplete, tampered, unsafe-path, or ownership-conflicting packages before replacing current data. Historical unit evidence passed; physical destination testing remains pending.

## Security boundaries and release work

The app uses its sandboxed container and validates internal/export paths and file ownership. It uses SHA-256 to detect report and backup asset changes; a hash is an integrity check, not encryption or a digital signature.

Before distribution, confirm file data-protection behavior on locked physical devices, system-backup behavior, network observation, permission copy, retention language, and App Store privacy labels. A real public privacy-policy URL and responsible contact are still required. None is supplied or claimed here.
