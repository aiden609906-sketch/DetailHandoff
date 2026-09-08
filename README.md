# DetailHandoff

DetailHandoff is an offline-first iPhone and iPad app for mobile auto detailers to capture before-and-after photos, document visible vehicle condition, collect a pre-service acknowledgment, and export a branded PDF report.

## Verification status

The integrated V1 source is **not yet release-ready**. The latest executed run
built the app and passed 133 unit tests, but its iPhone and iPad UI suites failed.
Focused corrections and a new disk-migration test are committed, but the follow-up
GitHub Actions run did not start because of an account billing/spending-limit block.
The final-review fixes add capture/revision access, acknowledgment integrity and
saved-record presentation, safe PDF restore typing, and a DiskSpace privacy manifest.
The current 149 unit-test methods, 9 UI-test methods, migration coverage, and release
screenshots remain unverified on macOS. Windows plist/resource and diff checks do
not establish an iOS build or test pass.

See the evidence-backed [acceptance record](docs/release/acceptance.md),
[privacy behavior](docs/release/privacy.md), and
[App Store handoff](docs/release/app-store.md). None claims signing,
physical-device testing, TestFlight distribution, or App Review.

## Product decisions

- US App Store launch
- English-first interface
- iPhone-first, iPad-compatible
- USD 9.99 paid download with lifetime access
- No account, subscription, in-app purchase, ads, cloud backend, or AI in V1
- Local jobs, guided photos, manual findings, customer acknowledgment, immutable report versions, backup/restore, photo export, recent deletion, and storage cleanup

Business records and metadata, including signature strokes, use SwiftData. Photos,
thumbnails, business logos, and generated PDFs use local files. Data leaves
the app through user-initiated system share/export interfaces; operating-system
device backups may also include the app container according to the user's settings.
Reinstalling or losing the device can lose local data without a usable backup.

## Documentation

- [Product design and PRD](docs/superpowers/specs/2026-09-03-detailhandoff-design.md)
- [Implementation plans](docs/superpowers/plans/)
- [V1 acceptance and evidence](docs/release/acceptance.md)
- [Privacy behavior](docs/release/privacy.md)
- [App Store handoff](docs/release/app-store.md)

## Build and test

XcodeGen and Xcode are required. On a Mac, from the repository root:

```bash
brew install xcodegen
xcodegen generate
open DetailHandoff.xcodeproj
```

To build for a generic iOS Simulator destination without code signing:

```bash
xcodebuild -project DetailHandoff.xcodeproj -scheme DetailHandoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

To run the complete scheme on an installed simulator:

```bash
xcodebuild test -project DetailHandoff.xcodeproj -scheme DetailHandoff -destination 'platform=iOS Simulator,name=<installed device>,OS=<installed runtime>'
```

Windows can edit and inspect this repository, but cannot run Xcode, XcodeGen,
`xcodebuild`, or the iOS Simulator. The current follow-up verification must run
on macOS after the GitHub Actions account block is resolved.

## Remaining release gates

At minimum: a green macOS build/unit/iPhone UI/iPad UI run with inspected
screenshots; a passing Phase 1 disk-migration test; physical iPhone and iPad
camera, permission, interruption, offline, and performance checks; Apple Developer
membership, account/team/signing configuration; verified product-name clearance;
real support and privacy-policy URLs; App Store assets and metadata; TestFlight
users; business agreements, tax, and banking; and App Review.

