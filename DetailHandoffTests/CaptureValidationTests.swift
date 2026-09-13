import XCTest
@testable import DetailHandoff

final class CaptureValidationTests: XCTestCase {
    // Removing the phase filter, accepting empty skip reasons, or treating any photo as coverage must fail these tests.
    func testRequiredSlotsNeedEvidenceOrMeaningfulSkipForEachPhase() {
        let empty = CaptureDocument.empty
        XCTAssertEqual(CaptureValidation.missingRequiredSlots(in: empty, phase: .before).count, 12)

        var skipped = empty
        skipped.skips = empty.slots.map {
            CaptureSkip(slotID: $0.id, phase: .before, reason: "Not accessible")
        }

        XCTAssertTrue(CaptureValidation.missingRequiredSlots(in: skipped, phase: .before).isEmpty)
        XCTAssertEqual(CaptureValidation.missingRequiredSlots(in: skipped, phase: .after).count, 12)
    }

    func testBlankSkipDoesNotCompleteRequiredSlot() {
        var document = CaptureDocument.empty
        document.skips = [CaptureSkip(slotID: "front", phase: .before, reason: " \n ")]

        XCTAssertEqual(
            CaptureValidation.missingRequiredSlots(in: document, phase: .before).map(\.id),
            CaptureSlot.standard.map(\.id)
        )
    }

    func testPhotoOnlyCompletesItsOwnSlotAndPhase() {
        var document = CaptureDocument.empty
        document.photos = [
            CapturedPhoto(slotID: "rear", phase: .before, imagePath: "rear.jpg", thumbnailPath: "rear-thumb.jpg")
        ]

        let missing = CaptureValidation.missingRequiredSlots(in: document, phase: .before)
        XCTAssertFalse(missing.contains(where: { $0.id == "rear" }))
        XCTAssertTrue(missing.contains(where: { $0.id == "front" }))
        XCTAssertEqual(CaptureValidation.missingRequiredSlots(in: document, phase: .after).count, 12)
    }

    func testOptionalSlotsDoNotBlockCompletion() {
        var document = CaptureDocument(
            slots: CaptureSlot.standard + [CaptureSlot(id: "roof", name: "Roof", isRequired: false)]
        )
        document.skips = CaptureSlot.standard.map {
            CaptureSkip(slotID: $0.id, phase: .before, reason: "Not accessible")
        }

        XCTAssertTrue(CaptureValidation.missingRequiredSlots(in: document, phase: .before).isEmpty)
    }
}
