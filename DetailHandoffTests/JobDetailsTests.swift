import SwiftData
import XCTest
@testable import DetailHandoff

final class JobDetailsTests: XCTestCase {
    @MainActor
    func testNewJobStoresIndependentTemplateSnapshot() throws {
        let container = try makeContainer()
        let template = CaptureTemplateOption(name: "Express", slots: [CaptureSlot(id: "front", name: "Front", isRequired: true)])
        let profile = try BusinessRepository(context: container.mainContext).createProfile(
            businessName: "Northstar",
            phone: "",
            email: "",
            configuration: BusinessConfiguration(services: [ServiceOption(name: "Express")], templates: [template], defaultTemplateID: template.id)
        )
        let job = try JobRepository(context: container.mainContext).createJob(customerName: "Avery", vehicleLabel: "Roadster", plate: "EV1", color: "Blue", serviceName: "Express", notes: "", template: template)

        var editedTemplate = template
        editedTemplate.slots[0].name = "Changed globally"
        try BusinessRepository(context: container.mainContext).updateDetails(
            profile,
            businessName: "Northstar",
            phone: "",
            email: "",
            disclaimer: profile.disclaimer,
            configuration: BusinessConfiguration(services: [ServiceOption(name: "Express")], templates: [editedTemplate], defaultTemplateID: editedTemplate.id)
        )
        let document = try CaptureRepository(context: container.mainContext, media: MediaStore(root: temporaryRoot())).document(for: job)

        XCTAssertEqual(document.slots, [CaptureSlot(id: "front", name: "Front", isRequired: true)])
        XCTAssertNotEqual(document.slots, editedTemplate.slots)
    }

    @MainActor
    func testUpdateDetailsPersistsOptionalContactAndLocationThroughFreshContext() throws {
        let container = try makeContainer()
        let repository = JobRepository(context: container.mainContext)
        let job = try repository.createJob(customerName: "Avery", vehicleLabel: "Roadster", plate: "EV1", color: "Blue", serviceName: "Wash", notes: "")
        let jobID = job.id

        try repository.updateDetails(job, customerName: " Avery Chen ", customerPhone: " 555-0123 ", customerEmail: " avery@example.com ", vehicleLabel: " Roadster EV ", plate: " EV1 ", color: " Blue ", serviceName: " Wash ", location: " 100 Main St ", notes: " Keep keys ")

        let fresh = ModelContext(container)
        let saved = try XCTUnwrap(try fresh.fetch(FetchDescriptor<JobRecord>(predicate: #Predicate { $0.id == jobID })).first)
        XCTAssertEqual(saved.customerName, "Avery Chen")
        XCTAssertEqual(saved.customerPhone, "555-0123")
        XCTAssertEqual(saved.customerEmail, "avery@example.com")
        XCTAssertEqual(saved.location, "100 Main St")
        XCTAssertEqual(saved.notes, "Keep keys")
    }

    @MainActor
    func testUpdateDetailsRestoresFieldsWhenSaveFailsAndRejectsFinalizedJob() throws {
        enum SaveFailure: Error { case simulated }
        let container = try makeContainer()
        let job = try JobRepository(context: container.mainContext).createJob(customerName: "Avery", vehicleLabel: "Roadster", plate: "EV1", color: "Blue", serviceName: "Wash", notes: "")
        let oldUpdatedAt = Date(timeIntervalSince1970: 1)
        job.updatedAt = oldUpdatedAt
        let failing = JobRepository(context: container.mainContext) { throw SaveFailure.simulated }

        XCTAssertThrowsError(try failing.updateDetails(job, customerName: "Changed", customerPhone: "", customerEmail: "", vehicleLabel: "Changed", plate: "Changed", color: "Changed", serviceName: "Changed", location: "", notes: "Changed"))
        XCTAssertEqual(job.customerName, "Avery")
        XCTAssertEqual(job.vehicleLabel, "Roadster")
        XCTAssertEqual(job.updatedAt, oldUpdatedAt)

        job.status = .finalized
        XCTAssertThrowsError(try JobRepository(context: container.mainContext).updateDetails(job, customerName: "Avery", customerPhone: "", customerEmail: "", vehicleLabel: "Roadster", plate: "EV1", color: "Blue", serviceName: "Wash", location: "", notes: "")) { error in
            XCTAssertEqual(error as? JobRepositoryError, .immutableJob)
        }
    }

    @MainActor
    func testSearchMatchesLocalYYYYMMDDDate() throws {
        let container = try makeContainer()
        let job = try JobRepository(context: container.mainContext).createJob(customerName: "Avery", vehicleLabel: "Roadster", plate: "EV1", color: "Blue", serviceName: "Wash", notes: "")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        job.createdAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 12)))

        XCTAssertEqual(JobRepository(context: container.mainContext).search([job], query: "2026-09-04").map(\.id), [job.id])
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: BusinessProfile.self, JobRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}
