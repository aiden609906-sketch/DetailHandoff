import Foundation

enum WorkflowPrimaryAction: Equatable {
    case advance(to: JobStatus)
    case reviewAndSealCurrentRevision
    case none
}

enum WorkflowPresentationPolicy {
    static func primaryAction(for status: JobStatus) -> WorkflowPrimaryAction {
        if status == .review {
            return .reviewAndSealCurrentRevision
        }

        guard let nextStatus = status.next else {
            return .none
        }

        return .advance(to: nextStatus)
    }
}
