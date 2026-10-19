import SwiftUI
import XCTest
@testable import DetailHandoff

final class WorkflowProgressLayoutTests: XCTestCase {
    func testAccessibilityTypeAllocatesMoreWidthThanStandardType() {
        let standardWidth = WorkflowProgressLayout.minimumStepWidth(for: .large)
        let accessibilityWidth = WorkflowProgressLayout.minimumStepWidth(for: .accessibility3)

        XCTAssertGreaterThan(accessibilityWidth, standardWidth)
    }

    func testProgressStateClassifiesCompletedCurrentAndUpcomingSteps() {
        XCTAssertEqual(
            WorkflowProgressLayout.state(for: .beforeCapture, current: .inProgress),
            .complete
        )
        XCTAssertEqual(
            WorkflowProgressLayout.state(for: .inProgress, current: .inProgress),
            .current
        )
        XCTAssertEqual(
            WorkflowProgressLayout.state(for: .afterCapture, current: .inProgress),
            .upcoming
        )
    }

    func testPersistentScrollIndicatorTracksHorizontalContentOffset() {
        let leading = WorkflowProgressLayout.scrollIndicatorMetrics(
            contentWidth: 1_000,
            viewportWidth: 400,
            contentMinX: 0,
            trackWidth: 100
        )
        let middle = WorkflowProgressLayout.scrollIndicatorMetrics(
            contentWidth: 1_000,
            viewportWidth: 400,
            contentMinX: -300,
            trackWidth: 100
        )
        let trailing = WorkflowProgressLayout.scrollIndicatorMetrics(
            contentWidth: 1_000,
            viewportWidth: 400,
            contentMinX: -600,
            trackWidth: 100
        )

        XCTAssertEqual(leading, .init(isScrollable: true, thumbWidth: 40, thumbOffset: 0))
        XCTAssertEqual(middle, .init(isScrollable: true, thumbWidth: 40, thumbOffset: 30))
        XCTAssertEqual(trailing, .init(isScrollable: true, thumbWidth: 40, thumbOffset: 60))
    }

    func testMinimumContentWidthDoesNotDependOnRuntimeGeometryMeasurement() {
        XCTAssertEqual(
            WorkflowProgressLayout.minimumContentWidth(
                stepCount: 6,
                stepWidth: 132,
                spacing: 8
            ),
            832
        )
    }

    func testPersistentScrollIndicatorFillsTrackWhenContentFits() {
        XCTAssertEqual(
            WorkflowProgressLayout.scrollIndicatorMetrics(
                contentWidth: 300,
                viewportWidth: 400,
                contentMinX: 0,
                trackWidth: 100
            ),
            .init(isScrollable: false, thumbWidth: 100, thumbOffset: 0)
        )
    }
}
