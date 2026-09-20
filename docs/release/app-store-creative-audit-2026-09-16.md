# App Store creative audit — 2026-09-16

This combined Product Design and accessibility-risk audit covers the 12 current marketing PNGs in `app-store-assets/iphone` and `app-store-assets/ipad`. Each source file was opened during this audit. It evaluates the store artwork, not the complete interactive app, and does not establish WCAG compliance or App Review acceptance.

## Decision

**Keep the dark-navy direction, but do not upload this screenshot set as final artwork.** The story and visual hierarchy are coherent, the UI is an exact simulator capture, and the privacy statement is now accurate. The remaining creative blocker is the conspicuously synthetic fixture content: solid-color image blocks labeled `evidence 1`, names such as `Complete Fixture Sedan`, and other `Fixture` copy reduce trust in a paid professional tool. On iPad, screens 01, 03, and 05 also devote most of the visible app surface to empty space, making the actual feature evidence too small in an App Store thumbnail.

## Six-step story

| Step | Screen pair | Health | Evidence and recommendation |
|---|---|---|---|
| 1 | Professional record | Needs revision | The value proposition and report action are clear. Replace `Complete Fixture Sedan`; on iPad, use a denser report state or a truthful crop that keeps the complete controls visible. |
| 2 | Guided capture | Needs revision | The Before-photo structure is understandable. Replace the solid red `evidence 1` block with a realistic fictional vehicle photo captured through the real fixture path. |
| 3 | Findings | Needs revision | Area, severity, note, and photo are represented. The small color block and large empty iPad canvas weaken credibility and legibility. |
| 4 | Acknowledgment | Needs revision | The screen communicates service context and customer acknowledgment without claiming legal enforceability. Replace fixture names, color blocks, and test-style signature with believable fictional data. |
| 5 | Seal and revise | Needs revision | Version history, checksum, Preview, Share, and Create revision support the claim. The iPad feature card is too small at store-preview scale. |
| 6 | Local control | Acceptable with final recheck | The subtitle correctly limits the claim to developer cloud service. The iPad capture visibly includes the system-backup caveat, product name, and real support email. |

## Strengths

- Consistent navy, white, and cyan palette matches the selected icon and keeps the six-frame sequence recognizable.
- Short headlines describe actual V1 behavior; no AI damage detection, guaranteed dispute outcome, cloud sync, or legal-protection claim is shown.
- Exact simulator UI is preserved inside the marketing frame rather than being redrawn.
- iPhone and iPad exports use the required native dimensions and are opaque RGB files.

## UX and accessibility risks

- Store-thumbnail readability is the main visible accessibility risk. The marketing headline is large, but several iPad UI labels are too small to carry the proof without opening the image.
- Muted subtitle text appears readable against the dark background in the inspected images, but screenshot inspection alone does not prove contrast across every compressed storefront rendering.
- Cyan is used with wording and size, not as the only carrier of meaning. The app itself still needs VoiceOver, Larger Text, Reduce Motion, rotation, and split-view checks on physical devices.
- The current synthetic evidence blocks look like placeholders. This is a trust problem rather than a false-feature problem, because the screenshots accurately show the implemented UI.

## Required creative pass

1. Replace only the screenshot-fixture data and images; do not alter production behavior for marketing.
2. Use realistic, fully fictional vehicle photos and identities with no license plate, address, phone number, or real customer data.
3. Recapture both device classes from a green CI run, regenerate all 12 frames with the existing renderer, and re-run dimension/opacity checks.
4. Reopen every final PNG at native resolution and at thumbnail scale before marking the set approved.

## Evidence limits

This audit did not test App Store compression, VoiceOver, touch targets, focus order, dynamic reflow, rotation, split view, or a signed build. The apparent missing icons in a few resized chat previews were disproved by original-resolution review and identical icon-region pixel hashes across all six frames on each platform; the committed PNGs contain the icon.
