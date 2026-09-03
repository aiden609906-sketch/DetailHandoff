# DetailHandoff

DetailHandoff is an offline-first iPhone and iPad app for mobile auto detailers to capture before-and-after photos, document visible vehicle condition, collect a pre-service acknowledgment, and export a branded PDF report.

## Product status

Phase 1 foundation is implemented on the `feature/phase-1-foundation` branch. It
contains the local SwiftData schema, first-run business setup, draft-job creation
and search, and the eight-stage workflow navigation skeleton. Camera capture,
customer signatures, PDF reports, report sealing, backup/restore, and release
verification are intentionally deferred to later phases.

## Product decisions

- US App Store launch
- English-first interface
- iPhone-first, iPad-compatible
- USD 9.99 paid download with lifetime access
- No account, subscription, ads, cloud backend, or AI in V1
- Local jobs, guided photos, manual findings, customer signature, PDF reports, and backups

## Documentation

- [Product design and PRD](docs/superpowers/specs/2026-09-03-detailhandoff-design.md)

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

To run the complete unit-test target:

```bash
xcodebuild test -project DetailHandoff.xcodeproj -scheme DetailHandoff -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest'
```

For a focused workflow-state test run:

```bash
xcodebuild test -project DetailHandoff.xcodeproj -scheme DetailHandoff -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -only-testing:DetailHandoffTests/JobStatusTests
```

Windows can edit and inspect this repository, but cannot run Xcode, XcodeGen,
`xcodebuild`, or the iOS Simulator. Build and test results must therefore be
collected on macOS (locally or through the repository's macOS GitHub Actions
workflow).

Phase 1 is offline and local-only: it contains no networking, analytics,
subscription, AI, or account/login integration. Later-phase capabilities are
not verified or claimed here.

