import XCTest
@testable import DetailHandoff

final class ReportPresentationPolicyTests: XCTestCase {
    // Catches hiding immutable historical reports while a new revision is under review.
    func testReviewKeepsHistoricalVersionsAvailableWhileAllowingDraftActions() {
        XCTAssertTrue(ReportPresentationPolicy.canPreviewDraft(for: .review))
        XCTAssertTrue(ReportPresentationPolicy.canSeal(for: .review))
        XCTAssertFalse(ReportPresentationPolicy.canCreateRevision(for: .review))
        XCTAssertTrue(ReportPresentationPolicy.canOpenStoredVersion(for: .review))
        XCTAssertTrue(ReportPresentationPolicy.canShareStoredVersion(for: .review))
        XCTAssertTrue(ReportPresentationPolicy.isDraftRevision(status: .review, sealedVersionCount: 4))
        XCTAssertFalse(ReportPresentationPolicy.isDraftRevision(status: .review, sealedVersionCount: 0))
    }

    // Catches exposing a new draft or seal control after a report has already become immutable.
    func testFinalizedStateExposesOnlyItsPermittedReportActions() {
        XCTAssertFalse(ReportPresentationPolicy.canPreviewDraft(for: .finalized))
        XCTAssertFalse(ReportPresentationPolicy.canSeal(for: .finalized))
        XCTAssertTrue(ReportPresentationPolicy.canCreateRevision(for: .finalized))
        XCTAssertTrue(ReportPresentationPolicy.canOpenStoredVersion(for: .finalized))
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
