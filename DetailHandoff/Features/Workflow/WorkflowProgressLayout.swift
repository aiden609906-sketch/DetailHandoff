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

    static func minimumContentWidth(
        stepCount: Int,
        stepWidth: CGFloat,
        spacing: CGFloat
    ) -> CGFloat {
        guard stepCount > 0 else { return 0 }
        return (CGFloat(stepCount) * stepWidth) + (CGFloat(stepCount - 1) * spacing)
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

    static func scrollIndicatorMetrics(
        contentWidth: CGFloat,
        viewportWidth: CGFloat,
        contentMinX: CGFloat,
        trackWidth: CGFloat
    ) -> WorkflowScrollIndicatorMetrics {
        let safeTrackWidth = max(trackWidth, 0)
        guard contentWidth > viewportWidth, viewportWidth > 0, safeTrackWidth > 0 else {
            return WorkflowScrollIndicatorMetrics(
                isScrollable: false,
                thumbWidth: safeTrackWidth,
                thumbOffset: 0
            )
        }

        let thumbWidth = max(24, safeTrackWidth * viewportWidth / contentWidth)
        let maximumContentOffset = contentWidth - viewportWidth
        let contentOffset = min(max(-contentMinX, 0), maximumContentOffset)
        let maximumThumbOffset = max(safeTrackWidth - thumbWidth, 0)
        let thumbOffset = maximumThumbOffset * contentOffset / maximumContentOffset

        return WorkflowScrollIndicatorMetrics(
            isScrollable: true,
            thumbWidth: thumbWidth,
            thumbOffset: thumbOffset
        )
    }
}

struct WorkflowScrollIndicatorMetrics: Equatable {
    let isScrollable: Bool
    let thumbWidth: CGFloat
    let thumbOffset: CGFloat
}
