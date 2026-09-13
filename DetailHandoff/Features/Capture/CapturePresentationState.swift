import Foundation

struct CaptureSlotPair: Equatable, Identifiable {
    let slot: CaptureSlot
    let beforePhotos: [CapturedPhoto]
    let afterPhotos: [CapturedPhoto]
    let beforeSkip: CaptureSkip?
    let afterSkip: CaptureSkip?

    var id: String { slot.id }
}

struct CapturePhasePresentation: Equatable {
    let photos: [CapturedPhoto]
    let skipReason: String?

    var showsEmptyState: Bool { photos.isEmpty && skipReason == nil }
}

enum CaptureStorageDecision: Equatable {
    case ready
    case warning(availableBytes: Int64)
    case unavailable
}

enum CapturePresentationState {
    static let lowStorageThreshold: Int64 = 250 * 1_024 * 1_024

    static func pairs(in document: CaptureDocument) -> [CaptureSlotPair] {
        document.slots.map { slot in
            CaptureSlotPair(
                slot: slot,
                beforePhotos: document.photos.filter { $0.slotID == slot.id && $0.phase == .before },
                afterPhotos: document.photos.filter { $0.slotID == slot.id && $0.phase == .after },
                beforeSkip: document.skips.first { $0.slotID == slot.id && $0.phase == .before },
                afterSkip: document.skips.first { $0.slotID == slot.id && $0.phase == .after }
            )
        }
    }

    static func storageDecision(availableBytes: Int64?) -> CaptureStorageDecision {
        guard let availableBytes else { return .unavailable }
        return availableBytes < lowStorageThreshold ? .warning(availableBytes: availableBytes) : .ready
    }

    static func phasePresentation(photos: [CapturedPhoto], skip: CaptureSkip?) -> CapturePhasePresentation {
        CapturePhasePresentation(photos: photos, skipReason: skip?.reason)
    }
}
