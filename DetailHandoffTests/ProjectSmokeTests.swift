import SwiftData
import XCTest
@testable import DetailHandoff

final class ProjectSmokeTests: XCTestCase {
    func testProductIdentity() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            "DetailHandoff"
        )
    }

    @MainActor
    func testBusinessProfileNameSurvivesSaveInSharedModelSchema() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BusinessProfile.self, JobRecord.self,
            configurations: configuration
        )
        let profile = BusinessProfile(businessName: "Northside Detail Co.")

        container.mainContext.insert(profile)
        try container.mainContext.save()

        let reloadedContext = ModelContext(container)
        let savedProfiles = try reloadedContext.fetch(FetchDescriptor<BusinessProfile>())

        XCTAssertEqual(savedProfiles.map(\.businessName), ["Northside Detail Co."])
    }
}
