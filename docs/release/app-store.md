# App Store handoff

Last updated: 2026-09-21

## Submission status

**Do not submit this revision yet.** Merged-main commit `97d931f` passed CI [`35573487842`](https://github.com/aiden609906-sketch/DetailHandoff/actions/runs/35573487842): app and Release builds, 149/0 unit tests, 13/0 UI tests on each selected iPhone and iPad simulator, screenshot-fixture exclusion, and attachment upload. The 12 App Store screenshots come from this run and passed the documented creative review. Product-owner screenshot signoff, physical-device checks, legal name clearance, signed-archive validation, account-owned metadata, Paid Apps Agreement, tax/banking setup, TestFlight, and App Review remain open. No publication is claimed.

## Commercial configuration

| Field | Intended V1 value | Verification state |
|---|---|---|
| Distribution | US App Store; iPhone and iPad | Product decision only; App Store Connect not verified |
| Language | English first | Source/UI direction; final copy review pending |
| Minimum OS | iOS/iPadOS 17.0 | Declared in `project.yml` |
| Price | USD 9.99 paid download, lifetime access | Must be configured and confirmed in App Store Connect |
| In-app purchases | None | No StoreKit/IAP implementation found; App Store Connect check pending |
| Subscription / ads / account paywall | None | No implementation found; metadata review pending |
| Product name | DetailHandoff working name | Name availability and legal/trademark clearance **not verified** |

USD 9.99 is the intended US storefront price, not an in-app price. Apple may represent it through a storefront price tier and add taxes or regional equivalents. Do not add an IAP, subscription, trial, account, or paywall to reproduce the purchase; the App Store paid-download setting is the commercial mechanism.

## English-first listing package

The copy-ready U.S. English package is stored in:

- `docs/release/app-store-metadata.en-US.json` — machine-readable source of truth.
- `docs/release/app-store-metadata.en-US.md` — copy-friendly product-page text and App Review notes.

The package includes name, subtitle, promotional text, description, keywords, initial release notes, reviewer navigation, category recommendations, paid-download intent, and a list of account-owned values that cannot be invented. `scripts/test-app-store-metadata.ps1` validates required text and Apple's current length limits. The revised draft is 13/30 name characters, 30/30 subtitle characters, 142/170 promotional-text characters, 1157/4000 description characters, and 92/100 keyword UTF-8 bytes. Apple does not require What's New text for an initial release; it is retained here as a handoff draft.

The copy describes the current binary and explicitly avoids promises of legal protection, guaranteed dispute outcomes, cloud sync, AI damage detection, or features outside V1. Product-name availability and legal/trademark clearance are still not verified.

## Permission copy

The generated Info.plist receives these source-controlled strings from `project.yml`:

- Camera: `DetailHandoff uses the camera to document vehicle condition before and after service.`
- Photo selection declaration: `DetailHandoff lets you import vehicle photos selected by you.` The current UI uses SwiftUI `PhotosPicker`; it does not request broad photo-library authorization.

Validate the camera permission prompt on physical iPhone and iPad for first denial, later denial/recovery, cancellation, backgrounding, and interrupted capture. Separately open and cancel the system photo picker and verify that no unnecessary broad Photo Library permission prompt appears. If the final binary still declares a photo-library purpose string that no code path requires, remove that declaration before submission. Screenshots used for the listing should not display private customer data or system permission prompts unless the store slot specifically calls for that context.

## Required creative assets

- `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` is the selected opaque 1024×1024 master and is referenced by `Contents.json`. Dimensions, RGB opacity, JSON syntax, and visual safe margins were checked locally; Xcode asset compilation and signed-archive validation remain required.
- Draft English screenshot sets are in `docs/release/app-store-assets/iphone` (1290×2796) and `docs/release/app-store-assets/ipad` (2048×2732). They use the selected dark-navy Product Design direction and exact simulator captures from green CI `35573487842`, with realistic fictional vehicle photos but no AI-rewritten app UI. Release builds exclude the screenshot-only photo catalog.
- The six-frame story covers report creation, guided Before capture, findings, acknowledgment, sealed revision history, and local-data/privacy controls. The current Product Design review is in `app-store-creative-audit-2026-09-21.md`. It passes the current creative draft after focused iPad framing, complete iPhone signature visibility, and a finding photo that matches the fictional scuff claim; product-owner signoff is still required.
- Review every image at native resolution for cropping, Dynamic Type overflow, private information, placeholder data, misleading status, and device chrome.
- Optional promotional art, preview video, and localization are not required by this handoff and have not been produced.

The 27 PNGs from CI `33936741128` remain failure diagnostics, not store assets. Earlier screenshot sources are superseded; CI `35573487842` is the source of the current store set. All 12 current PNGs were visually inspected and passed dimension/opaque-RGB checks. The creative audit passes; product-owner approval and store upload remain open.

## Pre-membership checks (2026-09-14)

- The revised English metadata uses 92/100 keyword UTF-8 bytes, avoiding duplicate terms from the name/subtitle. Re-run the validator before copying into App Store Connect; local length checks are not App Store Connect acceptance.
- All six iPhone PNGs are opaque RGB at 1290×2796; all six iPad PNGs are opaque RGB at 2048×2732. These are listed as accepted sizes in [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications). The icon master is opaque RGB at 1024×1024. The release archive and store upload remain unverified.
- The public support and privacy URLs both returned HTTP 200 on 2026-09-16. Recheck them immediately before submission and after any hosting change.
- Apple's public U.S. app search returned no exact `DetailHandoff` or `Detail Handoff` app-name match on 2026-09-16. The live USPTO/WIPO/EUIPO records and App Store Connect availability were **not** verified; see `name-clearance-precheck-2026-09-16.md`. This does **not** reserve the name or establish trademark clearance.
- A targeted iPhone simulator UI test creates a job, terminates and relaunches the app, then reopens that saved job (CI `34848170708`). This is not a physical-device force-quit or full-progress retention test. No verified airplane-mode complete-job/PDF run exists; those release gates remain open.

## Metadata and account checklist

- [x] Obtain a green merged-main run (CI `35573487842`, commit `97d931f`) with 149 unit tests and 13 UI tests on both iPhone and iPad. Files saving/cancellation remains a physical-device check.
- [ ] Verify the archived `PrivacyInfo.xcprivacy` declares DiskSpace reason `E174.1` for the actual capture/import storage check, without tracking or collected-data claims beyond the implementation. The built simulator resource test has passed.
- [x] Pass the Phase 1 on-disk migration fixture without losing baseline records (included in the 149-test run).
- [ ] Complete physical iPhone and iPad camera, permissions, interruption, offline, accessibility, performance, Files/share, backup/restore, deletion, and low-storage checks using `physical-device-checklist.zh-CN.md`.
- [ ] Confirm Apple Developer Program membership, legal account holder, team, bundle identifier, certificates, provisioning profiles, signing, entitlements, release archive, and upload validation.
- [ ] Perform product-name availability and legal/trademark clearance. No clearance is claimed.
- [x] Provide support contact `aiden609906@gmail.com` and publish the reachable support URL: `https://detailhandoff-support.aiden609906.chatgpt.site/`.
- [x] Publish the privacy policy URL: `https://detailhandoff-support.aiden609906.chatgpt.site/privacy/`.
- [ ] Complete category, age rating, copyright, seller/developer name, SKU, version/release notes, territories, paid-app price, App Store privacy responses, accessibility information, and export-compliance answers.
- [x] Prepare length-validated U.S. English product-page copy and truthful App Review notes for the current binary.
- [ ] Validate the selected 1024px icon and all asset warnings in the release archive; obtain product-owner signoff for the creatively reviewed iPhone/iPad screenshots, then upload approved assets. Synthetic demo imagery is disclosed and isolated from Release builds.
- [ ] Add truthful reviewer notes describing local data, camera/photo selection, synthetic review data, backup/restore, and any non-obvious navigation. No demo account is required by current source because there is no login.
- [ ] Accept paid-app and other business agreements; complete tax and banking information.
- [ ] Recruit TestFlight users, distribute a signed build, capture feedback, fix release blockers, and retest. No TestFlight activity is claimed.
- [ ] Submit to App Review only after the preceding gates close; record review questions and final decision. Approval is not claimed.

## Privacy-label preparation

Base App Store privacy responses on the final binary and the engineering behavior in `privacy.md`, then validate them with the responsible legal/account owner. Current source keeps business data locally and exposes only user-initiated export/share; it has no developer analytics or backend. System Files/share providers and operating-system backups are separate processing contexts. Static source review alone is not enough to make the final App Store privacy declaration.

## Release handoff rule

The release owner must attach the exact CI run, commit, device/runtime inventory, accepted screenshots, physical-device checklist, signed-archive validation, App Store Connect configuration, TestFlight evidence, and App Review status. A successful simulator CI run cannot close account, legal, contact, policy, physical-device, signing, commercial, TestFlight, business, or review gates.
