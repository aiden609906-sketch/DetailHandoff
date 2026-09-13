import Foundation

enum CaptureValidation {
    static func missingRequiredSlots(in document: CaptureDocument, phase: CapturePhase) -> [CaptureSlot] {
        document.slots.filter { slot in
            guard slot.isRequired else { return false }
            let hasPhoto = document.photos.contains { $0.slotID == slot.id && $0.phase == phase }
            let hasMeaningfulSkip = document.skips.contains {
                $0.slotID == slot.id
                    && $0.phase == phase
                    && !$0.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return !hasPhoto && !hasMeaningfulSkip
        }
    }
}
