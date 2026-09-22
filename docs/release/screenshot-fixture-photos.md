# Screenshot fixture photo provenance

Eight fictional vehicle photos were generated with the built-in image-generation tool for the `--ui-testing --screenshot-fixture complete` flow. They depict the same generic, unbranded silver sedan in an ordinary detailing bay. No customer, plate number, address, or real job is represented. The sources are in `DetailHandoff/Resources/ScreenshotFixtures.xcassets` and are intended only for Debug UI testing and draft App Store screenshots; Release builds exclude that catalog through `project.yml`.

## Prompt set

Shared prompt: *Natural, candid smartphone condition-documentation photo of the same unbranded silver compact sedan in a plain indoor detailing bay; landscape 4:3; neutral workshop lighting; honest pre-service texture; no people, logos, readable plates, text, watermark, collage, or UI.* The front image established the car and bay. Each subsequent image used the relevant earlier photo as a visual identity reference and requested one new inspection viewpoint:

| Asset | Requested viewpoint | Capture slots using it |
|---|---|---|
| `ScreenshotFront` | Straight-on front, including bumper, hood, and windshield | Front, front bumper, hood and windshield |
| `ScreenshotRear` | Straight-on rear, including bumper and trunk lid | Rear, rear bumper |
| `ScreenshotSide` | Driver-side profile | Driver side |
| `ScreenshotPassengerSide` | Passenger-side profile | Passenger side |
| `ScreenshotWheel` | Front driver-side wheel and tire close-up | Wheels and tires |
| `ScreenshotInterior` | Front seats, dashboard, and console from driver-side door | Front seats, dashboard and console |
| `ScreenshotRearSeats` | Rear bench from passenger-side door | Rear seats |
| `ScreenshotCargo` | Open trunk and cargo area | Trunk or cargo area |

The same fictional image set is used for Before and After in the automated fixture. It demonstrates the app's workflow, **not** a documented real-world detailing outcome. App Store review notes already disclose synthetic screenshot data. The 12 draft PNGs were regenerated from merged-main CI `35573487842` and visually inspected on 2026-09-21. Creative review passes, but they are not final upload assets until product-owner approval and the remaining release gates are complete; see `app-store-creative-audit-2026-09-21.md`.
