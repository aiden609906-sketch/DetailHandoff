# DetailHandoff Core Workflow UX Design

**Date:** 2026-10-20  
**Status:** Proposed for implementation  
**Scope:** Workflow progress, primary creation actions, multi-photo capture, completion acknowledgment review, and customer-facing PDF identity

## Intent

Make the app's main workflow self-explanatory for a detailing business: creating a job and recording a finding must be obvious, each vehicle view must accept as many photos as the operator needs, a customer must be able to inspect Before/After evidence before the completion acknowledgment, and the final report must emphasize the service provider and job rather than the software that created it.

Success means:

- the custom workflow scrollbar visibly follows horizontal scrolling;
- a first-time operator immediately finds the primary create actions;
- a view can hold one or many photos from either camera or photo library without changing the stored document schema;
- the completion-acknowledgment workflow exposes the same `Inspect photo pairs` action used elsewhere;
- the PDF retains audit identifiers while removing duplicate or empty provider contact presentation.

## 1. Workflow Progress Indicator

### Behavior

The gray track remains visible whenever the workflow steps overflow horizontally. Its blue thumb changes position continuously while the user drags the workflow steps and reaches the corresponding end of the track at the trailing edge.

The thumb width continues to represent the visible fraction of the workflow content. When all steps fit, the custom indicator is hidden.

### Implementation boundary

The horizontal workflow component will report its real scroll offset through a dedicated scroll-observation boundary instead of inferring movement from a SwiftUI layout preference whose frame does not reliably update on device. The existing pure `WorkflowProgressLayout.scrollIndicatorMetrics` calculation remains the single source of truth for thumb width and position.

The implementation must support the deployment target, iOS 17, and must not rely on iOS 18-only scroll geometry APIs.

## 2. Prominent Primary Creation Actions

### Jobs

The Jobs screen displays a full-width, visually prominent `Create new job` button above the job content. It uses the app accent color, a plus icon, a large control size, and an explicit accessibility identifier. It remains available when the list is empty, populated, or filtered to no results.

The small navigation-bar plus is removed to avoid two competing creation controls.

### Findings

The Condition findings screen displays a matching full-width `Add finding` button at the top of the list whenever the job is mutable. The toolbar-only plus is removed. Finalized and archived jobs remain read-only and do not show the button.

Both actions share one reusable primary-action visual treatment so the same operation hierarchy is recognizable across the app, including large accessibility text.

## 3. Flexible Multi-Photo Capture

### User experience

Every capture slot displays an `Add photos` action. Selecting it offers:

- `Take photos`: open the camera for one photo. After a successful save, let the operator choose `Take another photo` or `Done`. Repeating the action appends photos to the same slot.
- `Choose from library`: open the system multi-selection picker. Selecting one or many images appends every successfully imported image to the same slot.

There is no business-defined per-slot photo limit. The system picker and available device storage are the practical limits. Existing low-storage and unavailable-storage protections continue to run before camera capture and library import.

The interface never labels an append operation `Retake`. Existing thumbnails remain individually previewable and removable. Removal continues to be blocked when a photo is linked to a finding.

### Data and compatibility

`CaptureDocument.photos` already supports multiple `CapturedPhoto` records with the same `slotID` and phase, so no schema migration is required. Existing jobs, backups, findings, exports, report snapshots, and sealed report versions remain readable.

Camera captures and library imports use the existing `CaptureRepository.addPhoto` path. A partial library import keeps successfully saved photos, stops at the first failed item, and presents the current error; it does not roll back unrelated photos.

## 4. Completion Acknowledgment Evidence Access

At the `Awaiting completion acknowledgment` workflow step, the action group contains:

1. the prominent `Record completion acknowledgment` action; and
2. the existing secondary `Inspect photo pairs` navigation action.

`Inspect photo pairs` opens the same `PhotoPairView` used by other workflow states. The operator or customer can review evidence grouped by vehicle view, open images at full size, return through normal navigation, and then record the completion acknowledgment.

The acknowledgment form is not given a second embedded photo-pair implementation. Its current summary remains available, while the canonical comparison experience stays in `PhotoPairView`.

## 5. Customer-Facing PDF Identity

### Keep

- service-provider name;
- optional provider logo;
- provider phone and email only when nonblank;
- report number;
- report revision (`Version N`), because it distinguishes sealed revisions and is not the app version;
- sealed timestamp;
- job, vehicle, customer, service, evidence, findings, acknowledgments, and disclaimer information.

### Change

- Show the provider name only once in the first-page identity area instead of repeating it as both page branding and body content.
- Build contact lines conditionally so an empty phone or email never produces `Phone:` or `Email:` with no value.
- Keep a compact provider name in subsequent page headers, where it identifies the issuer without repeating the full contact block.
- Do not add the DetailHandoff app version or Apple account information to the report.
- Rename business settings fields to `Customer-facing phone (optional)` and `Customer-facing email (optional)` so users understand that entered values may appear in reports. The app does not infer either value from the Apple ID or App Store Connect account.

The report number, report revision, and sealed timestamp remain visible audit metadata and must not be described as software metadata.

## Error Handling and Safety

- Scroll observation failure must leave a usable scrollable workflow; the indicator may fall back to the leading position but must not block interaction.
- Camera cancellation adds nothing and returns to the capture screen without an error.
- A failed photo save presents an error and never advances workflow state.
- Existing storage warnings and retry behavior apply before every new capture/import session.
- The creation buttons preserve current repository validation and error presentation.
- Existing immutable-job rules remain unchanged for finalized and archived jobs.

## Accessibility

- Full-width creation actions expose descriptive labels and identifiers, not icon-only controls.
- Buttons remain readable at accessibility Dynamic Type sizes without clipping.
- The workflow scrollbar is decorative and stays hidden from VoiceOver; workflow steps retain their complete/current/upcoming accessibility values.
- `Inspect photo pairs` remains keyboard- and VoiceOver-activatable as a standard navigation control.

## Verification

Automated coverage will include:

- scroll-indicator metrics at leading, middle, and trailing offsets, plus an integration/UI assertion that a real drag changes the thumb position;
- Jobs creation action in empty, populated, and no-search-result states;
- Findings creation action for mutable jobs and its absence for immutable jobs;
- one-photo and repeated multi-photo camera flows, one- and multi-selection library imports, cancellation, partial failure, and low-storage handling;
- availability of `Inspect photo pairs` during completion acknowledgment and navigation back to the workflow;
- PDF text extraction checks for one provider-name identity block, conditional contacts, retained report revision, and absence of app-version text;
- the complete unit and iPhone/iPad UI test suites before release.

## Out of Scope

- changing report numbering or sealed-report revision semantics;
- changing the capture document schema solely to count photos;
- automatically pairing individual Before and After photos beyond grouping them by capture slot;
- adding cloud storage or cross-device photo synchronization;
- redesigning the acknowledgment signature data model.
