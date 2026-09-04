import SwiftData
import XCTest
@testable import DetailHandoff

final class BusinessRepositoryTests: XCTestCase {
    @MainActor
    func testCreateProfileRequiresNonemptyIdentityAndOnlyOneProfile() throws {
        let container = try makeContainer()
        let repository = BusinessRepository(context: container.mainContext)

        XCTAssertThrowsError(try repository.createProfile(businessName: "  ", phone: "", email: "", configuration: .standard)) { error in
            XCTAssertEqual(error as? BusinessRepositoryError, .blankBusinessName)
        }

        _ = try repository.createProfile(businessName: "Northstar Detailing", phone: "", email: "", configuration: .standard)

        XCTAssertThrowsError(try repository.createProfile(businessName: "Second Shop", phone: "", email: "", configuration: .standard)) { error in
            XCTAssertEqual(error as? BusinessRepositoryError, .profileAlreadyExists)
        }
    }

    func testConfigurationRequiresValidDefaultAndUniqueNonemptySlots() {
        let service = ServiceOption(name: "Full detail")
        let template = CaptureTemplateOption(name: "Standard", slots: [
            CaptureSlot(id: "front", name: "Front", isRequired: true),
            CaptureSlot(id: "front", name: "Front again", isRequired: true)
        ])
        let invalid = BusinessConfiguration(services: [service], templates: [template], defaultTemplateID: UUID())

        XCTAssertThrowsError(try invalid.validated()) { error in
            XCTAssertEqual(error as? BusinessConfigurationError, .invalidDefaultTemplate)
        }

        let duplicateSlots = BusinessConfiguration(services: [service], templates: [template], defaultTemplateID: template.id)
        XCTAssertThrowsError(try duplicateSlots.validated()) { error in
            XCTAssertEqual(error as? BusinessConfigurationError, .duplicateSlotID("front"))
        }
    }

    @MainActor
    func testUpdateDetailsPreservesReportLedgerAndPersistsConfigurationThroughFreshContext() throws {
        let container = try makeContainer()
        let repository = BusinessRepository(context: container.mainContext)
        let profile = try repository.createProfile(businessName: "Northstar Detailing", phone: "", email: "", configuration: .standard)
        let profileID = profile.id
        let ledger = Data([0xD0, 0x0D])
        profile.reportNumberLedgerData = ledger
        try container.mainContext.save()
        let template = CaptureTemplateOption(name: "Express", slots: [CaptureSlot(id: "front", name: "Front", isRequired: true)])
        let configuration = BusinessConfiguration(services: [ServiceOption(name: "Express detail")], templates: [template], defaultTemplateID: template.id)

        try repository.updateDetails(profile, businessName: "  Northstar Mobile  ", phone: " 555-0100 ", email: " hello@example.com ", disclaimer: " Updated disclaimer ", configuration: configuration)

        let freshContext = ModelContext(container)
        let saved = try XCTUnwrap(try freshContext.fetch(FetchDescriptor<BusinessProfile>(predicate: #Predicate { $0.id == profileID })).first)
        XCTAssertEqual(saved.businessName, "Northstar Mobile")
        XCTAssertEqual(saved.phone, "555-0100")
        XCTAssertEqual(saved.email, "hello@example.com")
        XCTAssertEqual(saved.disclaimer, "Updated disclaimer")
        XCTAssertEqual(saved.reportNumberLedgerData, ledger)
        XCTAssertEqual(try BusinessRepository(context: freshContext).configuration(for: saved), configuration)
    }

    @MainActor
    func testFailedBusinessSaveRestoresAllEditableFieldsWithoutChangingLedger() throws {
        enum SaveFailure: Error { case simulated }
        let container = try makeContainer()
        let profile = BusinessProfile(businessName: "Northstar", phone: "555", email: "old@example.com")
        let ledger = Data([0xAB])
        profile.reportNumberLedgerData = ledger
        container.mainContext.insert(profile)
        try container.mainContext.save()
        let repository = BusinessRepository(context: container.mainContext) { throw SaveFailure.simulated }

        XCTAssertThrowsError(try repository.updateDetails(profile, businessName: "Changed", phone: "999", email: "new@example.com", disclaimer: "Changed", configuration: .standard))

        XCTAssertEqual(profile.businessName, "Northstar")
        XCTAssertEqual(profile.phone, "555")
        XCTAssertEqual(profile.email, "old@example.com")
        XCTAssertEqual(profile.reportNumberLedgerData, ledger)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: BusinessProfile.self, JobRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}
