import SwiftData
import XCTest
@testable import DetailHandoff

final class CaptureDocumentTests: XCTestCase {
    func testStandardSlotsHaveStableRequiredIdentifiersAndNames() {
        XCTAssertEqual(CaptureSlot.standard.map(\.id), ["front", "rear", "driver-side", "passenger-side", "front-bumper", "rear-bumper", "hood-windshield", "wheels-tires", "front-seats", "rear-seats", "dashboard-console", "trunk"])
        XCTAssertEqual(CaptureSlot.standard.map(\.name), ["Front", "Rear", "Driver side", "Passenger side", "Front bumper", "Rear bumper", "Hood and windshield", "Wheels and tires", "Front seats", "Rear seats", "Dashboard and console", "Trunk or cargo area"])
        XCTAssertTrue(CaptureSlot.standard.allSatisfy(\.isRequired))
    }

    func testEmptyDocumentStartsAtVersionOneWithStandardSlots() {
        XCTAssertEqual(CaptureDocument.empty.schemaVersion, 1)
        XCTAssertEqual(CaptureDocument.empty.slots.count, 12)
        XCTAssertTrue(CaptureDocument.empty.photos.isEmpty)
        XCTAssertTrue(CaptureDocument.empty.skips.isEmpty)
        XCTAssertTrue(CaptureDocument.empty.findings.isEmpty)
    }

    @MainActor
    func testDocumentForNilCaptureDataReturnsFreshStandardSnapshot() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let repository = CaptureRepository(context: container.mainContext, media: MediaStore(root: makeTemporaryRoot()))
        XCTAssertEqual(try repository.document(for: job), .empty)
    }

    @MainActor
    func testDocumentRejectsMalformedOrUnsupportedPersistedData() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let repository = CaptureRepository(context: container.mainContext, media: MediaStore(root: makeTemporaryRoot()))
        job.captureData = Data([0xFF])
        XCTAssertThrowsError(try repository.document(for: job))
        job.captureData = try JSONEncoder().encode(CaptureDocument(schemaVersion: 2, slots: [], photos: [], skips: [], findings: []))
        XCTAssertThrowsError(try repository.document(for: job))
    }
}

@MainActor
func makeContainer() throws -> ModelContainer {
    try ModelContainer(for: BusinessProfile.self, JobRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
}

@MainActor
func makeSavedJob(in container: ModelContainer) throws -> JobRecord {
    let job = JobRecord(customerName: "Marcus Lee", vehicleLabel: "2021 Honda Accord", plate: "7HKL248", color: "Pearl White", serviceName: "Full detail", notes: "")
    container.mainContext.insert(job)
    try container.mainContext.save()
    return job
}

func makeTemporaryRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("DetailHandoffTests", isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
}
