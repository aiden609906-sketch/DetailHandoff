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
}
