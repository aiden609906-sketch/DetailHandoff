import XCTest
@testable import DetailHandoff

final class WorkflowPresentationPolicyTests: XCTestCase {
    func testReviewRoutesToReportSealingInsteadOfGenericAdvance() {
        XCTAssertEqual(
            WorkflowPresentationPolicy.primaryAction(for: .review),
            .reviewAndSealCurrentRevision
        )
    }

    func testOrdinaryStepsAdvanceAndArchivedHasNoPrimaryAction() {
        XCTAssertEqual(
            WorkflowPresentationPolicy.primaryAction(for: .draft),
            .advance(to: .beforeCapture)
        )
        XCTAssertEqual(
            WorkflowPresentationPolicy.primaryAction(for: .finalized),
            .advance(to: .archived)
        )
        XCTAssertEqual(WorkflowPresentationPolicy.primaryAction(for: .archived), .none)
    }
}
