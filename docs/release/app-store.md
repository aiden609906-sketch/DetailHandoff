# App Store handoff

Last updated: 2026-09-07

## Submission status

**Do not submit this revision.** Corrected iPhone/iPad UI verification and the Phase 1 migration test have not run because the latest GitHub Actions attempt was blocked before all steps by account billing/spending limits. Physical-device, signing, TestFlight, business, and metadata gates are also open. There has been no archive signing, TestFlight distribution, App Review submission, approval, or publication.

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

## English-first listing draft

Working title: `DetailHandoff`

Working subtitle: `Before & after vehicle reports`

Draft description:

> Document vehicle condition before service, guide consistent Before and After photos, record manual findings, collect a pre-service acknowledgment, and create a branded PDF handoff. DetailHandoff keeps core job data on the device and works without an account or developer cloud service. Export reports, job photo packages, and full backups when you choose.

This copy must be reviewed against the final binary and accepted screenshots. It must not promise legal protection, guaranteed dispute outcomes, cloud sync, AI damage detection, or features outside V1.

Candidate keywords, subject to metadata-length and market review: `auto detailing,vehicle inspection,before after,car photos,service report,PDF`.

## Permission copy

The generated Info.plist receives these source-controlled strings from `project.yml`:

- Camera: `DetailHandoff uses the camera to document vehicle condition before and after service.`
- Photo selection declaration: `DetailHandoff lets you import vehicle photos selected by you.` The current UI uses SwiftUI `PhotosPicker`; it does not request broad photo-library authorization.

Validate the camera permission prompt on physical iPhone and iPad for first denial, later denial/recovery, cancellation, backgrounding, and interrupted capture. Separately open and cancel the system photo picker and verify that no unnecessary broad Photo Library permission prompt appears. If the final binary still declares a photo-library purpose string that no code path requires, remove that declaration before submission. Screenshots used for the listing should not display private customer data or system permission prompts unless the store slot specifically calls for that context.

## Required creative assets

- `Assets.xcassets/AppIcon.appiconset` declares a universal iOS 1024×1024 slot, but the catalog currently contains no referenced artwork filename. Final original icon artwork and Xcode asset validation are required.
- Accepted App Store screenshots do not yet exist. Run the corrected UI suite to generate inspection candidates, then capture final App Store Connect sizes from approved simulator/physical states with synthetic data only.
- Required screenshot story: Jobs/search; guided Before capture; findings; acknowledgment or customer unavailable; paired Before/After review; branded PDF preview; immutable report history; backup/storage controls.
- Review every image at native resolution for cropping, Dynamic Type overflow, private information, placeholder data, misleading status, and device chrome.
- Optional promotional art, preview video, and localization are not required by this handoff and have not been produced.

The 27 PNGs from CI `33936741128` are failure diagnostics, not store assets: inspection found large-text leakage and clipping plus incomplete navigation/system-surface paths.

## Metadata and account checklist

- [ ] Resolve GitHub Actions billing/spending limits and obtain a green current macOS build, 137/0 unit target, iPhone UI, and iPad UI run with inspected attachments.
- [ ] Pass the Phase 1 on-disk migration fixture without losing baseline records.
- [ ] Complete physical iPhone and iPad camera, permissions, interruption, offline, accessibility, performance, Files/share, backup/restore, deletion, and low-storage checks.
- [ ] Confirm Apple Developer Program membership, legal account holder, team, bundle identifier, certificates, provisioning profiles, signing, entitlements, release archive, and upload validation.
- [ ] Perform product-name availability and legal/trademark clearance. No clearance is claimed.
- [ ] Provide a real support contact and reachable support URL. No address or URL is invented here.
- [ ] Publish a real privacy policy and enter its reachable URL. No policy URL is claimed here.
- [ ] Complete category, age rating, copyright, seller/developer name, SKU, version/release notes, territories, paid-app price, App Store privacy responses, accessibility information, and export-compliance answers.
- [ ] Upload final 1024px icon artwork and approved iPhone/iPad screenshots; validate all asset warnings in the release archive.
- [ ] Add truthful reviewer notes describing local data, camera/photo selection, synthetic review data, backup/restore, and any non-obvious navigation. No demo account is required by current source because there is no login.
- [ ] Accept paid-app and other business agreements; complete tax and banking information.
- [ ] Recruit TestFlight users, distribute a signed build, capture feedback, fix release blockers, and retest. No TestFlight activity is claimed.
- [ ] Submit to App Review only after the preceding gates close; record review questions and final decision. Approval is not claimed.

## Privacy-label preparation

Base App Store privacy responses on the final binary and the engineering behavior in `privacy.md`, then validate them with the responsible legal/account owner. Current source keeps business data locally and exposes only user-initiated export/share; it has no developer analytics or backend. System Files/share providers and operating-system backups are separate processing contexts. Static source review alone is not enough to make the final App Store privacy declaration.

## Release handoff rule

The release owner must attach the exact CI run, commit, device/runtime inventory, accepted screenshots, physical-device checklist, signed-archive validation, App Store Connect configuration, TestFlight evidence, and App Review status. A successful simulator CI run cannot close account, legal, contact, policy, physical-device, signing, commercial, TestFlight, business, or review gates.
