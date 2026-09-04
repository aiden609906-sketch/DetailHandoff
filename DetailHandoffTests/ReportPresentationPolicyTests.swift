import XCTest
@testable import DetailHandoff

final class ReportPresentationPolicyTests: XCTestCase {
    // Catches exposing a new draft or seal control after a report has already become immutable.
    func testReviewAndFinalizedStatesExposeOnlyTheirPermittedReportActions() {
        XCTAssertTrue(ReportPresentationPolicy.canPreviewDraft(for: .review))
        XCTAssertTrue(ReportPresentationPolicy.canSeal(for: .review))
        XCTAssertFalse(ReportPresentationPolicy.canCreateRevision(for: .review))
        XCTAssertFalse(ReportPresentationPolicy.canShareStoredVersion(for: .review))

        XCTAssertFalse(ReportPresentationPolicy.canPreviewDraft(for: .finalized))
        XCTAssertFalse(ReportPresentationPolicy.canSeal(for: .finalized))
        XCTAssertTrue(ReportPresentationPolicy.canCreateRevision(for: .finalized))
        XCTAssertTrue(ReportPresentationPolicy.canShareStoredVersion(for: .finalized))
    }

    // Catches archived reports losing access to retained originals or gaining an editing route.
    func testArchivedReportsRemainViewableAndShareableButCannotBeRevised() {
        XCTAssertTrue(ReportPresentationPolicy.canOpenStoredVersion(for: .archived))
        XCTAssertTrue(ReportPresentationPolicy.canShareStoredVersion(for: .archived))
        XCTAssertFalse(ReportPresentationPolicy.canPreviewDraft(for: .archived))
        XCTAssertFalse(ReportPresentationPolicy.canSeal(for: .archived))
        XCTAssertFalse(ReportPresentationPolicy.canCreateRevision(for: .archived))
    }
}
