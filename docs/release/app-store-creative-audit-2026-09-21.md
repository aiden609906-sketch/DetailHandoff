# App Store creative audit — 2026-09-21

Scope: the six iPhone and six iPad draft marketing PNGs in `app-store-assets/`, regenerated from successful simulator CI [`35514766784`](https://github.com/aiden609906-sketch/DetailHandoff/actions/runs/35514766784) at commit `b1d27eb`. Every output was opened and inspected in this audit. This is a visual/content review, not an App Review, legal, or accessibility approval.

## Decision

**Keep the selected dark-navy direction and the new fictional vehicle imagery; do not upload this draft set yet.** The earlier solid-color evidence blocks and fixture-style vehicle name are gone, the headline spacing and single-photo grammar are corrected, and the privacy claim remains qualified. The iPad story still loses impact to empty app space, while the iPhone acknowledgment frame does not show the recorded signature. The finding text calls out a small scuff that cannot be verified from its tiny full-car thumbnail.

## Six-step story

| Step | Screen pair | Health | Evidence and next change |
|---|---|---|---|
| 1 | Professional record | Needs polish | Report actions are legible on iPhone; iPad places a small action group above a large empty white area. Use a denser, truthful report state for the iPad frame. |
| 2 | Guided capture | Needs polish | A realistic fictional front photo replaces the color block, and `1 photo` is grammatical. One small photo beside several empty capture rows weakly supports “every angle”; capture a richer but accurate state. |
| 3 | Findings | Needs revision | Severity, area, note, and supporting photo are visible. The whole-car thumbnail does not visibly substantiate the stated scuff; use a matching close-up or change the fictional finding to match the photo. The iPad frame is mostly empty. |
| 4 | Acknowledgment | Needs revision | The iPad frame shows service, vehicle photos, customer name, timestamp, and signature. The iPhone frame stops above the signature, so it does not show the core action promised by the headline. Recapture the phone after scrolling to the acknowledgment. |
| 5 | Seal and revise | Needs polish | Version, checksum, Preview, Share, and Create revision are visible. On iPad, the version card is small above a broad empty area; use a more focused truthful state. |
| 6 | Local control | Acceptable with pre-upload recheck | The iPad Settings capture shows the system-backup caveat and support email. The iPhone capture crops those below the fold, while the marketing subtitle correctly limits “no cloud” to developer service. |

## Strengths and risks

- The selected icon, navy/white/cyan treatment, tilted-report composition, and six-part sequence remain consistent.
- Source app UI comes from the actual simulator run; generated photos are fixture data, not AI-redrawn controls or real customer records. The photo catalog is excluded from the Release build.
- Each pair is an opaque 24-bit RGB PNG at its intended 1290×2796 or 2048×2732 size.
- At store-thumbnail size, iPad interface labels in frames 01, 03, and 05 will be hard to read. Screenshot inspection cannot prove VoiceOver behavior, contrast after storefront compression, or physical-device Dynamic Type/reflow.
- “Scratch · Minor” describes fictional test data; the associated photo is too small to verify a real mark. Do not imply these images prove a documented real-world service outcome.

## Evidence limits

The audit did not test App Store compression, signed builds, Apple review acceptance, VoiceOver, keyboard/focus order, rotation, split view, or physical camera behavior. No real customer/vehicle data or real Before/After service result was used. The 12 images are useful design drafts and CI-backed UI evidence, but final screenshot creative approval remains open.
