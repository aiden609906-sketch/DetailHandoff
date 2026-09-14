# Pre-membership release audit — 2026-09-14

This is a release-preparation evidence review, not App Store submission approval or legal advice. No Apple Developer membership is required for the checks recorded here. The per-image table below records the **initial** screenshot set from CI `34740399131`; see the remediation follow-up below for the current set.

## Latest automated evidence and image provenance

- Latest verified merged-main CI before the current branch: [run 34828946923](https://github.com/aiden609906-sketch/DetailHandoff/actions/runs/34828946923), commit `e0d07ff`: app build, 149/0 unit tests, 11/0 iPhone UI tests, and 11/0 iPad UI tests passed. The current isolated candidate [run 34848586983, attempt 2](https://github.com/aiden609906-sketch/DetailHandoff/actions/runs/34848586983/attempts/2), commit `a21c5fc`, passed the build, 149/0 unit tests, and 12/0 UI tests on each simulator, including job relaunch persistence. Attempt 1 had one intermittent iPhone Files-exporter UI-test recognition failure.
- Current marketing images: six `iphone` PNGs at 1290×2796 and six `ipad` PNGs at 2048×2732. These were regenerated from exact simulator captures in green [run 34803310219](https://github.com/aiden609906-sketch/DetailHandoff/actions/runs/34803310219), commit `5d901de`, then rendered into marketing frames. They are **not** screenshots of the latest CI run.
- All 12 derived PNGs were opened and visually reviewed on 2026-09-14. Synthetic fixture names/plates/photos are visible; no real customer identity or contact details were observed. The fixture's color-block images are conspicuously synthetic and require a marketing decision before upload.

## Per-image copy and visual review

| Device | Frame | Visible story | Review decision |
|---|---:|---|---|
| iPhone | 01 | Report creation and vehicle condition record | No misleading claim or real customer data observed; final creative approval pending. |
| iPhone | 02 | Guided Before photos | Fixture evidence is synthetic. In-app `1 photos across 12 views` has an English grammar issue; polish before final capture. |
| iPhone | 03 | Manual finding with linked evidence | Shows a synthetic red `Fixture evidence 1` image; no automatic damage-detection claim. Consider more representative sample imagery. |
| iPhone | 04 | Customer acknowledgment | Synthetic fixture identity/signature; no claim of legal enforceability observed. Final creative approval pending. |
| iPhone | 05 | Sealed report/version history | Claim matches implemented sealed-version workflow; final creative approval pending. |
| iPhone | 06 | Local data/privacy Settings | Phone crop does not show the Support section, but the source screen still contains its placeholder and overly broad cloud wording. **Regenerate after Settings correction.** |
| iPad | 01 | Report creation and vehicle condition record | No misleading claim or real customer data observed; wide app content leaves substantial blank space. |
| iPad | 02 | Guided Before photos | Synthetic evidence and the same `1 photos` grammar issue; wide content leaves substantial blank space. |
| iPad | 03 | Manual finding with linked evidence | Synthetic red fixture block is prominent; wide content leaves substantial blank space. |
| iPad | 04 | Customer acknowledgment | Synthetic fixture identity/signature; wide content leaves substantial blank space. |
| iPad | 05 | Sealed report/version history | Claim matches implemented workflow; wide content leaves substantial blank space. |
| iPad | 06 | Local data/privacy Settings | **Blocked:** visibly says `Add a real support contact to your release checklist before distribution.` App screen also says `No account, analytics, or cloud service is used.` This lacks the system-backup caveat in the privacy handoff and can imply no cloud copy ever exists. `Detail Handoff` also differs from the listing's `DetailHandoff`. |

The marketing frame's `No account, analytics, or developer cloud service` is more precise than the app's Settings text. Preserve the distinction between no developer cloud sync and possible operating-system iCloud/computer backup. Do not upload frame 06 from either device class until app copy and captures are updated and re-reviewed. The wide iPad whitespace and synthetic evidence art are quality concerns, not proven policy violations.

## Core-flow evidence gap

- A targeted iPhone simulator UI test now proves that a newly created job remains available and opens after app process termination/relaunch (CI `34848170708`). A DEBUG-only preserve-store flag makes this possible without weakening ordinary UI fixture isolation. This does not prove that photos, signature, sealed PDF, or a complete job survive a physical-device force-quit.
- No complete-job/PDF run under a verified disconnected network state was found. Static source review found no `URLSession` or CloudKit business-data path, but that cannot replace an airplane-mode end-to-end test.
- Required physical run: enable airplane mode, create or open a representative job, complete Before/After evidence and acknowledgment, seal/open/share a PDF, force-quit the app, relaunch, and verify the job, photos, signature/unavailable reason, and sealed PDF persist. Repeat on a supported iPhone and iPad; record device/OS/build, screenshots, and any failure.

## Name, privacy, and public pages

- `DetailHandoff` remains a **working name**. An exact-phrase indexed public web/App Store search on 2026-09-14 found no exact result. This is not App Store Connect availability, USPTO clearance, international clearance, or a similar-mark search. The live USPTO database requires its interactive interface and was not successfully queried in this audit. Search confusingly similar marks in relevant software/services classes and obtain qualified advice where appropriate. See [USPTO federal trademark searching guidance](https://www.uspto.gov/trademarks/search/federal-trademark-searching).
- [Support](https://detailhandoff-support.aiden609906.chatgpt.site/) and [Privacy Policy](https://detailhandoff-support.aiden609906.chatgpt.site/privacy/) each returned HTTP 200 on 2026-09-14 and included `aiden609906@gmail.com`. Both mention local records, user-initiated sharing/backup, and the 30-day Recently Deleted window; the privacy page also distinguishes system iCloud backup from developer cloud sync. Availability is a point-in-time check, not a hosting guarantee.
- `privacy.md` and the published policy are directionally consistent on local storage, export/share, backup destination, system backup, tracking/analytics, and retention. The app's Settings wording and placeholder Support text are the material inconsistencies to correct. Final App Store privacy labels still require review against the signed binary and physical network observation.

## Frame-06 remediation follow-up — 2026-09-14

- Source cause: `SettingsView.swift` hard-coded a pre-release Support placeholder, omitted the system-backup caveat, used `cloud service` without distinguishing developer sync, and displayed `Detail Handoff` with inconsistent spacing. The screenshot renderer reproduced that app UI faithfully; editing the PNG alone would not fix the app.
- RED evidence: isolated [CI 34802742503](https://github.com/aiden609906-sketch/DetailHandoff/actions/runs/34802742503) ran the two new Settings UI tests against the old app; both failed for the missing user-visible backup/sync wording and support email. The temporary narrowed workflow configuration was restored before the fix run.
- GREEN evidence: [CI 34803310219](https://github.com/aiden609906-sketch/DetailHandoff/actions/runs/34803310219), code commit `5d901de`, passed the app build, 149/0 unit tests, and 11/0 UI tests on each iPhone and iPad, including both new Settings tests. The run exported and uploaded fresh screenshot attachments for both devices.
- All 12 marketing PNGs were regenerated from that green run; all are opaque RGB at the required native dimensions. Both refreshed frame-06 images were inspected at native resolution. The iPad image visibly shows `System device backups may include app data.`, `DetailHandoff`, and the real `aiden609906@gmail.com` link, with no old placeholder or absolute no-cloud claim. The iPhone crop ends after the first Privacy row; it does not display the backup caveat or support email, but its marketing subtitle accurately limits the claim to a developer cloud service.
- The old frame-06 factual blocker is **resolved**. This does not approve the whole creative set: the synthetic fixture imagery and iPad whitespace observations from the initial review still require a final marketing decision. Offline/force-quit, name clearance, signing, and App Store account gates are unchanged.

## Release decision

**Do not upload without final creative approval or submit the app.** The Settings copy and frame-06 recapture are complete, but synthetic fixture imagery and wide iPad whitespace need a release-owner decision. Re-test offline/relaunch on real devices, complete name clearance, and keep the public pages reachable. Signing, TestFlight, App Store Connect business/configuration, and App Review remain separate gates.
