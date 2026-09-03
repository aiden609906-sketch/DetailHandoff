import SwiftUI

enum WorkflowProgressStepState: Equatable {
    case complete
    case current
    case upcoming

    var accessibilityValue: String {
        switch self {
        case .complete:
            "complete"
        case .current:
            "current step"
        case .upcoming:
            "not started"
        }
    }
}

enum WorkflowProgressLayout {
    static func minimumStepWidth(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 196 : 132
    }

    static func state(
        for status: JobStatus,
        current currentStatus: JobStatus
    ) -> WorkflowProgressStepState {
        guard let currentIndex = JobStatus.allCases.firstIndex(of: currentStatus),
              let statusIndex = JobStatus.allCases.firstIndex(of: status) else {
            return .upcoming
        }

        if statusIndex < currentIndex {
            return .complete
        }

        return statusIndex == currentIndex ? .current : .upcoming
    }
}
