import XCTest
@testable import DetailHandoff

final class JobsListViewStateTests: XCTestCase {
    func testContentStateShowsFirstJobMessageWhenThereAreNoActiveJobs() {
        XCTAssertEqual(
            JobsListContentState.classify(activeJobCount: 0, visibleJobCount: 0),
            .firstJob
        )
    }

    func testContentStateShowsNoResultsWhenActiveJobsDoNotMatchSearch() {
        XCTAssertEqual(
            JobsListContentState.classify(activeJobCount: 1, visibleJobCount: 0),
            .noSearchResults
        )
    }

    func testContentStateShowsJobsWhenSearchReturnsMatches() {
        XCTAssertEqual(
            JobsListContentState.classify(activeJobCount: 1, visibleJobCount: 1),
            .jobs
        )
    }
}
