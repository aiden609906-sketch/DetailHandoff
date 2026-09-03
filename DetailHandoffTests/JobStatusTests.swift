import XCTest
@testable import DetailHandoff

final class JobStatusTests: XCTestCase {
    func testHappyPathTransitionsAreAllowed() {
        let path: [JobStatus] = [
            .draft,
            .beforeCapture,
            .awaitingAcknowledgment,
            .inProgress,
            .afterCapture,
            .review,
            .finalized,
            .archived
        ]

        for pair in zip(path, path.dropFirst()) {
            XCTAssertTrue(pair.0.canTransition(to: pair.1))
            XCTAssertEqual(pair.0.next, pair.1)
        }
    }

    func testFinalizedCannotReturnToEditableState() {
        XCTAssertFalse(JobStatus.finalized.canTransition(to: .review))
        XCTAssertFalse(JobStatus.archived.canTransition(to: .draft))
    }

    func testDisplayNamesAreCustomerReadableEnglish() {
        XCTAssertEqual(JobStatus.beforeCapture.displayName, "Before photos")
        XCTAssertEqual(JobStatus.awaitingAcknowledgment.displayName, "Awaiting acknowledgment")
        XCTAssertEqual(JobStatus.finalized.displayName, "Finalized")
    }
}
