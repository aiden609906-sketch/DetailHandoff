# App Store screenshot set

These English-first draft screenshots implement the selected dark-navy Product Design direction with exact UI captures from green CI run `34803310219` (code commit `5d901de`). All 12 frames were regenerated from that run's iPhone and iPad attachment manifests on 2026-09-14. The previous set came from CI `34740399131` and is superseded.

## Upload order

1. A professional record. Every time.
2. Capture every angle. Stay consistent.
3. Record what you see. Right where it matters.
4. Confirm before service. Keep the context.
5. Seal the report. Keep every revision.
6. Your records. Your control.

## Native output

- `iphone`: 1290×2796 PNG, opaque RGB
- `ipad`: 2048×2732 PNG, opaque RGB

Both sizes are accepted by the current App Store Connect screenshot specification. Recheck Apple's specification immediately before upload because supported device classes can change.

The refreshed iPad frame 06 visibly includes the system-backup caveat, `DetailHandoff`, and the real support email; the old support placeholder is absent. The iPhone frame 06 crops below the first Privacy row, so its app capture does not show the backup caveat or email; its marketing subtitle explicitly limits the no-cloud statement to a developer cloud service. Final creative approval remains separate from this factual correction.

## Regeneration

Download the full successful UI-test artifact so it contains `TestAttachments-iPhone` and `TestAttachments-iPad`, then run:

```powershell
./scripts/render-app-store-screenshots.ps1 -ArtifactRoot <artifact-directory> -Platform iPhone
./scripts/render-app-store-screenshots.ps1 -ArtifactRoot <artifact-directory> -Platform iPad
```

The renderer resolves each capture by its human-readable label in the test attachment `manifest.json`, so exported filenames can change between CI runs. It keeps the source app screenshots intact, adds the approved marketing frame and copy, and exports opaque PNG files at the required dimensions.
