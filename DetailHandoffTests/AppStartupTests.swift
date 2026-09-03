import SwiftData
import XCTest
@testable import DetailHandoff

final class AppStartupTests: XCTestCase {
    @MainActor
    func testFailureWaitsForExplicitRetryBeforeOpeningStore() throws {
        enum StartupFailure: Error {
            case simulated
        }

        let container = try makeTestContainer()
        var attempts = 0
        let startup = AppStartup {
            attempts += 1
            if attempts == 1 {
                throw StartupFailure.simulated
            }
            return container
        }

        guard case .failed = startup.state else {
            return XCTFail("Expected startup to preserve a recoverable failure state")
        }
        XCTAssertEqual(attempts, 1)

        startup.retry()

        guard case let .ready(retriedContainer) = startup.state else {
            return XCTFail("Expected explicit retry to open the local store")
        }
        XCTAssertTrue(retriedContainer === container)
        XCTAssertEqual(attempts, 2)
    }

    @MainActor
    func testSuccessfulStartupOpensStoreOnFirstAttempt() throws {
        let container = try makeTestContainer()
        var attempts = 0
        let startup = AppStartup {
            attempts += 1
            return container
        }

        guard case let .ready(loadedContainer) = startup.state else {
            return XCTFail("Expected startup to open the local store")
        }
        XCTAssertTrue(loadedContainer === container)
        XCTAssertEqual(attempts, 1)
    }

    @MainActor
    private func makeTestContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: BusinessProfile.self, JobRecord.self,
            configurations: configuration
        )
    }
}
