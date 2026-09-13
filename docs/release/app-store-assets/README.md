# App Store screenshot set

These English-first draft screenshots implement the selected dark-navy Product Design direction with exact UI captures from green CI run `34597284958`, attempt 2.

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

## Regeneration

Download the full successful UI-test artifact so it contains `TestAttachments-iPhone` and `TestAttachments-iPad`, then run:

```powershell
./scripts/render-app-store-screenshots.ps1 -ArtifactRoot <artifact-directory> -Platform iPhone
./scripts/render-app-store-screenshots.ps1 -ArtifactRoot <artifact-directory> -Platform iPad
```

The renderer keeps the source app screenshots intact, adds the approved marketing frame and copy, and exports opaque PNG files at the required dimensions.
