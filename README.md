# DetailHandoff

DetailHandoff is an offline-first iPhone and iPad app for mobile auto detailers to capture before-and-after photos, document visible vehicle condition, collect a pre-service acknowledgment, and export a branded PDF report.

## Verification status

The integrated V1 source has passed its current automated release gate. GitHub
Actions run `34560087867`, attempt 2, built commit `9199120`, passed all 149 unit
tests, and passed all 9 UI tests on both an iPhone 17 Pro and an iPad Pro 13-inch
(M5), using iOS 26.5 simulators. The run exported 30 attachments per device;
representative phone, tablet, Files exporter, report, and accessibility screenshots
were inspected at native resolution. This evidence does not replace the physical-
device, signing, TestFlight, business, or App Review gates listed below.

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
- [Public support site](https://detailhandoff-support.aiden609906.chatgpt.site/)
- [Public privacy policy](https://detailhandoff-support.aiden609906.chatgpt.site/privacy/)

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
`xcodebuild`, or the iOS Simulator. The cited GitHub Actions run supplies the
current macOS simulator evidence.

## Remaining release gates

Remaining gates include physical iPhone and iPad camera, permission, interruption,
offline, accessibility, Files-provider, and performance checks; Apple Developer
membership and signing; product-name clearance; final account-owned App Store
metadata; icon validation in the signed archive; TestFlight; business
agreements, tax and banking; and App Review.

