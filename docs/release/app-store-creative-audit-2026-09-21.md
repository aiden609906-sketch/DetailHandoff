# App Store creative audit — 2026-09-21

Scope: the six iPhone and six iPad marketing PNGs in `app-store-assets/`, regenerated from successful merged-main simulator CI [`35573487842`](https://github.com/aiden609906-sketch/DetailHandoff/actions/runs/35573487842) at commit `97d931f`. Every output was opened and inspected after rendering. This is a visual/content review, not an App Review, legal, signed-build, physical-device, or accessibility approval.

## Decision

**Creative review passes for the current English screenshot draft.** The selected dark-navy, white, and cyan direction remains consistent. The previously open composition issues are resolved: iPad frames 01, 03, and 05 use focused truthful crops instead of presenting broad empty app space; frame 03 uses a fictional close-up that visibly matches the bumper-scuff finding; and iPhone frame 04 shows the saved customer name, timestamp, and complete signature.

The images may move to product-owner signoff and eventual App Store Connect upload after the remaining account, legal, signed-archive, and physical-device gates are complete. This decision does not claim Apple acceptance or name clearance.

## Six-step story

| Step | Screen pair | Health | Evidence |
|---|---|---|---|
| 1 | Professional record | Pass | Both devices show the report identity and the Preview, Seal, and acknowledgment actions. The iPad composition focuses the meaningful report region without altering the simulator UI. |
| 2 | Guided capture | Pass with product note | The real capture screen shows the guided position list and a fictional vehicle photo. It demonstrates the workflow structure, not a completed twelve-angle job. |
| 3 | Findings | Pass | Kind, severity, position, note, and supporting evidence are visible. The linked fictional close-up visibly shows the described minor front-bumper scuff. |
| 4 | Acknowledgment | Pass | Both devices show recorded acknowledgment context. The iPhone composition now includes the saved customer, timestamp, and complete signature; the iPad view retains the broader service and evidence context. |
| 5 | Seal and revise | Pass | Version identifier, sealed time, checksum, Preview, Share, and Create revision are visible. The iPad composition focuses the stored-version controls. |
| 6 | Local control | Pass with pre-upload recheck | The privacy wording is limited to developer services. The iPad Settings capture also shows the system-backup caveat and support email. Recheck the published support/privacy URLs immediately before upload. |

## Integrity and presentation checks

- App UI is taken from the actual CI simulator captures. The renderer crops and frames those captures but does not redraw their controls or invent app states.
- Vehicle imagery is fictional screenshot-fixture data. The close-up in frame 03 is synthetic demo evidence, not a real customer record or claimed service result.
- CI verifies the screenshot-only photo catalog is excluded from the Release build.
- All 12 outputs are opaque 24-bit RGB PNGs at 1290×2796 for iPhone or 2048×2732 for iPad.
- No support placeholder, private customer data, real plate, third-party logo, or absolute “no backup/cloud anywhere” claim was observed.
- Text remains readable in the reviewed native files; storefront compression and physical-device appearance remain outside this audit.

## Evidence limits

This audit does not test App Store compression, Apple review acceptance, VoiceOver, keyboard/focus order, rotation, split view, physical camera behavior, signed archives, or legal rights to the working product name. Product-owner approval remains required before upload, and every image must stay paired with the binary represented by CI `35573487842` or a later equivalently verified build.
