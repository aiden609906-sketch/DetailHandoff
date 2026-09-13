import XCTest
@testable import DetailHandoff

final class CapturePresentationStateTests: XCTestCase {
    // A pairing implementation that matches positions rather than slot IDs would mix evidence here.
    func testPairsPhotosOnlyWithTheSameSlotAcrossPhases() {
        let frontBefore = CapturedPhoto(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            slotID: "front",
            phase: .before,
            imagePath: "front-before.jpg",
            thumbnailPath: "front-before-thumb.jpg"
        )
        let rearAfter = CapturedPhoto(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            slotID: "rear",
            phase: .after,
            imagePath: "rear-after.jpg",
            thumbnailPath: "rear-after-thumb.jpg"
        )
        let frontAfter = CapturedPhoto(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            slotID: "front",
            phase: .after,
            imagePath: "front-after.jpg",
            thumbnailPath: "front-after-thumb.jpg"
        )
        let document = CaptureDocument(
            slots: [
                CaptureSlot(id: "front", name: "Front", isRequired: true),
                CaptureSlot(id: "rear", name: "Rear", isRequired: true)
            ],
            photos: [frontBefore, rearAfter, frontAfter]
        )

        let pairs = CapturePresentationState.pairs(in: document)

        XCTAssertEqual(pairs.map(\.slot.id), ["front", "rear"])
        XCTAssertEqual(pairs[0].beforePhotos.map(\.id), [frontBefore.id])
        XCTAssertEqual(pairs[0].afterPhotos.map(\.id), [frontAfter.id])
        XCTAssertEqual(pairs[1].beforePhotos.map(\.id), [])
        XCTAssertEqual(pairs[1].afterPhotos.map(\.id), [rearAfter.id])
    }

    // A storage failure must not silently open capture or import as though capacity were known.
    func testStorageDecisionTreatsUnknownCapacityAsBlockedWithRetry() {
        XCTAssertEqual(
            CapturePresentationState.storageDecision(availableBytes: nil),
            .unavailable
        )
    }

    func testStorageDecisionWarnsBelowImportantUsageThreshold() {
        XCTAssertEqual(
            CapturePresentationState.storageDecision(availableBytes: 249 * 1_024 * 1_024),
            .warning(availableBytes: 249 * 1_024 * 1_024)
        )
        XCTAssertEqual(
            CapturePresentationState.storageDecision(availableBytes: 250 * 1_024 * 1_024),
            .ready
        )
    }

    // A review renderer must preserve both kinds of saved evidence when a skipped view later gains a photo.
    func testPhasePresentationRetainsPhotosAndSkipReasonTogether() {
        let photo = CapturedPhoto(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            slotID: "front",
            phase: .before,
            imagePath: "front-before.jpg",
            thumbnailPath: "front-before-thumb.jpg"
        )

        let presentation = CapturePresentationState.phasePresentation(
            photos: [photo],
            skip: CaptureSkip(slotID: "front", phase: .before, reason: "Vehicle blocked")
        )

        XCTAssertEqual(presentation.photos.map(\.id), [photo.id])
        XCTAssertEqual(presentation.skipReason, "Vehicle blocked")
        XCTAssertFalse(presentation.showsEmptyState)
    }
}
