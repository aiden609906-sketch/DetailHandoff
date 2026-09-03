import Foundation

enum JobStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case beforeCapture
    case awaitingAcknowledgment
    case inProgress
    case afterCapture
    case review
    case finalized
    case archived

    var id: String { rawValue }

    var next: JobStatus? {
        switch self {
        case .draft: .beforeCapture
        case .beforeCapture: .awaitingAcknowledgment
        case .awaitingAcknowledgment: .inProgress
        case .inProgress: .afterCapture
        case .afterCapture: .review
        case .review: .finalized
        case .finalized: .archived
        case .archived: nil
        }
    }

    func canTransition(to candidate: JobStatus) -> Bool {
        next == candidate
    }

    var displayName: String {
        switch self {
        case .draft: "Draft"
        case .beforeCapture: "Before photos"
        case .awaitingAcknowledgment: "Awaiting acknowledgment"
        case .inProgress: "In progress"
        case .afterCapture: "After photos"
        case .review: "Ready to review"
        case .finalized: "Finalized"
        case .archived: "Archived"
        }
    }
}
