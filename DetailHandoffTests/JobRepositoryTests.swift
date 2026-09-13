import SwiftData
import XCTest
@testable import DetailHandoff

final class JobRepositoryTests: XCTestCase {
    @MainActor
    func testCreateJobStoresTrimmedDraft() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BusinessProfile.self, JobRecord.self,
            configurations: configuration
        )
        let repository = JobRepository(context: container.mainContext)

        let job = try repository.createJob(
            customerName: "  Marcus Lee  ",
            vehicleLabel: "  2021 Honda Accord  ",
            plate: "  7HKL248  ",
            color: "  Pearl White  ",
            serviceName: "  Full detail  ",
            notes: "  Driveway gate code in message  "
        )
        let jobID = job.id
        let createdAt = job.createdAt
        let reloadedContext = ModelContext(container)
        let descriptor = FetchDescriptor<JobRecord>(
            predicate: #Predicate { $0.id == jobID }
        )
        let savedJob = try XCTUnwrap(try reloadedContext.fetch(descriptor).first)

        XCTAssertEqual(savedJob.customerName, "Marcus Lee")
        XCTAssertEqual(savedJob.vehicleLabel, "2021 Honda Accord")
        XCTAssertEqual(savedJob.plate, "7HKL248")
        XCTAssertEqual(savedJob.color, "Pearl White")
        XCTAssertEqual(savedJob.serviceName, "Full detail")
        XCTAssertEqual(savedJob.notes, "Driveway gate code in message")
        XCTAssertEqual(savedJob.status, .draft)
        XCTAssertEqual(savedJob.createdAt, createdAt)
        XCTAssertEqual(savedJob.updatedAt, createdAt)
    }

    @MainActor
    func testCreateJobRemovesPendingJobWhenSaveFails() throws {
        enum SaveFailure: Error {
            case simulated
        }

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BusinessProfile.self, JobRecord.self,
            configurations: configuration
        )
        let repository = JobRepository(context: container.mainContext) {
            throw SaveFailure.simulated
        }

        XCTAssertThrowsError(
            try repository.createJob(
                customerName: "Marcus Lee",
                vehicleLabel: "2021 Honda Accord",
                plate: "7HKL248",
                color: "Pearl White",
                serviceName: "Full detail",
                notes: ""
            )
        )
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<JobRecord>()).isEmpty)
    }

    @MainActor
    func testAdvanceMovesDraftToBeforeCaptureAndUpdatesTimestamp() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BusinessProfile.self, JobRecord.self,
            configurations: configuration
        )
        let repository = JobRepository(context: container.mainContext)
        let job = try repository.createJob(
            customerName: "Marcus Lee",
            vehicleLabel: "2021 Honda Accord",
            plate: "7HKL248",
            color: "Pearl White",
            serviceName: "Full detail",
            notes: ""
        )

        let oldUpdatedAt = Date(timeIntervalSince1970: 1)
        job.updatedAt = oldUpdatedAt
        let jobID = job.id

        try repository.advance(job)
        let reloadedContext = ModelContext(container)
        let descriptor = FetchDescriptor<JobRecord>(
            predicate: #Predicate { $0.id == jobID }
        )
        let savedJob = try XCTUnwrap(try reloadedContext.fetch(descriptor).first)

        XCTAssertEqual(savedJob.customerName, "Marcus Lee")
        XCTAssertEqual(savedJob.vehicleLabel, "2021 Honda Accord")
        XCTAssertEqual(savedJob.plate, "7HKL248")
        XCTAssertEqual(savedJob.color, "Pearl White")
        XCTAssertEqual(savedJob.serviceName, "Full detail")
        XCTAssertEqual(savedJob.notes, "")
        XCTAssertEqual(savedJob.status, .beforeCapture)
        XCTAssertGreaterThan(savedJob.updatedAt, oldUpdatedAt)
    }

    @MainActor
    func testAdvanceUpdatesTimestampForOrdinaryTransitionsBeforeSealing() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BusinessProfile.self, JobRecord.self,
            configurations: configuration
        )
        let repository = JobRepository(context: container.mainContext)
        let job = try repository.createJob(
            customerName: "Marcus Lee",
            vehicleLabel: "2021 Honda Accord",
            plate: "7HKL248",
            color: "Pearl White",
            serviceName: "Full detail",
            notes: ""
        )

        for expectedStatus in JobStatus.allCases.dropFirst().prefix(5) {
            if job.status == .beforeCapture {
                job.captureData = try JSONEncoder().encode(completedCaptureDocument(for: .before))
            } else if job.status == .awaitingAcknowledgment {
                try AcknowledgmentRepository(context: container.mainContext).markUnavailable(
                    job: job,
                    reason: "Customer left keys with the office"
                )
            } else if job.status == .afterCapture {
                job.captureData = try JSONEncoder().encode(completedCaptureDocument(for: .after))
            }
            let oldUpdatedAt = Date(timeIntervalSince1970: 1)
            job.updatedAt = oldUpdatedAt

            try repository.advance(job)

            XCTAssertEqual(job.status, expectedStatus)
            XCTAssertGreaterThan(job.updatedAt, oldUpdatedAt)
        }
    }

    @MainActor
    func testAdvanceBlocksIncompleteBeforeCaptureWithoutChangingStatusOrTimestamp() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        job.status = .beforeCapture
        let oldUpdatedAt = Date(timeIntervalSince1970: 1)
        job.updatedAt = oldUpdatedAt

        XCTAssertThrowsError(try JobRepository(context: container.mainContext).advance(job)) { error in
            XCTAssertEqual(
                error as? JobRepositoryError,
                .incompleteCapture(phase: .before, missingSlots: CaptureSlot.standard)
            )
        }
        XCTAssertEqual(job.status, .beforeCapture)
        XCTAssertEqual(job.updatedAt, oldUpdatedAt)
    }

    @MainActor
    func testAdvanceBlocksCorruptCaptureWithoutChangingStatusOrTimestamp() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        job.status = .afterCapture
        job.captureData = Data([0xFF])
        let oldUpdatedAt = Date(timeIntervalSince1970: 1)
        job.updatedAt = oldUpdatedAt

        XCTAssertThrowsError(try JobRepository(context: container.mainContext).advance(job)) { error in
            XCTAssertEqual(error as? JobRepositoryError, .corruptCapture(phase: .after))
        }
        XCTAssertEqual(job.status, .afterCapture)
        XCTAssertEqual(job.updatedAt, oldUpdatedAt)
    }

    @MainActor
    func testAdvanceRestoresStatusAndTimestampWhenSaveFails() throws {
        enum SaveFailure: Error, Equatable {
            case simulated
        }

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BusinessProfile.self, JobRecord.self,
            configurations: configuration
        )
        let job = try JobRepository(context: container.mainContext).createJob(
            customerName: "Marcus Lee",
            vehicleLabel: "2021 Honda Accord",
            plate: "7HKL248",
            color: "Pearl White",
            serviceName: "Full detail",
            notes: ""
        )
        let oldUpdatedAt = Date(timeIntervalSince1970: 1)
        job.updatedAt = oldUpdatedAt
        let repository = JobRepository(context: container.mainContext) {
            throw SaveFailure.simulated
        }

        XCTAssertThrowsError(try repository.advance(job)) { error in
            XCTAssertEqual(error as? SaveFailure, .simulated)
        }

        XCTAssertEqual(job.status, .draft)
        XCTAssertEqual(job.updatedAt, oldUpdatedAt)
    }

    @MainActor
    func testAdvanceFromAwaitingAcknowledgmentRequiresCurrentRecordAndSetsServiceStart() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        job.status = .awaitingAcknowledgment
        job.captureData = try JSONEncoder().encode(completedCaptureDocument(for: .before))
        XCTAssertThrowsError(try JobRepository(context: container.mainContext).advance(job)) { error in
            XCTAssertEqual(error as? JobRepositoryError, .missingAcknowledgment)
        }
        try AcknowledgmentRepository(context: container.mainContext).markUnavailable(job: job, reason: "Customer left keys with the office")

        try JobRepository(context: container.mainContext).advance(job)

        XCTAssertEqual(job.status, .inProgress)
        XCTAssertNotNil(job.serviceStartedAt)
    }

    @MainActor
    func testAdvanceFromAwaitingAcknowledgmentRejectsStaleRecordWithoutChangingWorkflowTimes() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        job.status = .awaitingAcknowledgment
        job.captureData = try JSONEncoder().encode(completedCaptureDocument(for: .before))
        try AcknowledgmentRepository(context: container.mainContext).markUnavailable(job: job, reason: "Customer left keys with the office")
        var alteredDocument = completedCaptureDocument(for: .before)
        alteredDocument.skips[0].reason = "Covered by a parked vehicle"
        job.captureData = try JSONEncoder().encode(alteredDocument)
        let oldUpdatedAt = Date(timeIntervalSince1970: 1)
        job.updatedAt = oldUpdatedAt

        XCTAssertThrowsError(try JobRepository(context: container.mainContext).advance(job)) { error in
            XCTAssertEqual(error as? JobRepositoryError, .staleAcknowledgment)
        }
        XCTAssertEqual(job.status, .awaitingAcknowledgment)
        XCTAssertNil(job.serviceStartedAt)
        XCTAssertEqual(job.updatedAt, oldUpdatedAt)
    }

    @MainActor
    func testAdvanceFromInProgressSetsServiceFinish() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        job.status = .inProgress

        try JobRepository(context: container.mainContext).advance(job)

        XCTAssertEqual(job.status, .afterCapture)
        XCTAssertNotNil(job.serviceFinishedAt)
    }

    @MainActor
    func testAdvanceRejectsArchivedJobWithNoNextStatusError() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BusinessProfile.self, JobRecord.self,
            configurations: configuration
        )
        let repository = JobRepository(context: container.mainContext)
        let job = try repository.createJob(
            customerName: "Marcus Lee",
            vehicleLabel: "2021 Honda Accord",
            plate: "7HKL248",
            color: "Pearl White",
            serviceName: "Full detail",
            notes: ""
        )
        job.status = .archived
        let oldUpdatedAt = Date(timeIntervalSince1970: 1)
        job.updatedAt = oldUpdatedAt

        XCTAssertThrowsError(try repository.advance(job)) { error in
            XCTAssertEqual(error as? JobRepositoryError, .noNextStatus)
        }
        XCTAssertEqual(job.status, .archived)
        XCTAssertEqual(job.updatedAt, oldUpdatedAt)
    }

    @MainActor
    func testSearchMatchesCustomerVehicleAndPlateCaseInsensitively() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BusinessProfile.self, JobRecord.self,
            configurations: configuration
        )
        let repository = JobRepository(context: container.mainContext)
        let customerMatch = try repository.createJob(
            customerName: "MARCUS LEE",
            vehicleLabel: "2021 Honda Accord",
            plate: "7HKL248",
            color: "Pearl White",
            serviceName: "Full detail",
            notes: ""
        )
        let vehicleMatch = try repository.createJob(
            customerName: "Avery Chen",
            vehicleLabel: "Roadster EV",
            plate: "EV2026",
            color: "Black",
            serviceName: "Wash",
            notes: ""
        )
        let plateMatch = try repository.createJob(
            customerName: "Jordan Kim",
            vehicleLabel: "2023 Subaru Outback",
            plate: "AbC-123",
            color: "Blue",
            serviceName: "Interior detail",
            notes: ""
        )

        XCTAssertEqual(
            repository.search([customerMatch, vehicleMatch, plateMatch], query: "marcus").map(\.id),
            [customerMatch.id]
        )
        XCTAssertEqual(
            repository.search([customerMatch, vehicleMatch, plateMatch], query: "ROAD").map(\.id),
            [vehicleMatch.id]
        )
        XCTAssertEqual(
            repository.search([customerMatch, vehicleMatch, plateMatch], query: "abc-123").map(\.id),
            [plateMatch.id]
        )
    }

    @MainActor
    func testSearchExcludesDeletedRecordsAndSortsNewestFirst() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BusinessProfile.self, JobRecord.self,
            configurations: configuration
        )
        let repository = JobRepository(context: container.mainContext)
        let oldJob = try repository.createJob(
            customerName: "Old Customer",
            vehicleLabel: "2018 Honda Civic",
            plate: "OLD001",
            color: "Gray",
            serviceName: "Wash",
            notes: ""
        )
        let newJob = try repository.createJob(
            customerName: "New Customer",
            vehicleLabel: "2024 Honda Civic",
            plate: "NEW001",
            color: "White",
            serviceName: "Wash",
            notes: ""
        )
        let deletedJob = try repository.createJob(
            customerName: "Deleted Customer",
            vehicleLabel: "2020 Honda Civic",
            plate: "DELETE1",
            color: "Black",
            serviceName: "Wash",
            notes: ""
        )
        oldJob.createdAt = Date(timeIntervalSince1970: 1)
        newJob.createdAt = Date(timeIntervalSince1970: 2)
        deletedJob.deletedAt = Date()

        XCTAssertEqual(
            repository.search([oldJob, deletedJob, newJob], query: "").map(\.id),
            [newJob.id, oldJob.id]
        )
    }

    @MainActor
    func testUnknownPersistedStatusDefaultsToDraft() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BusinessProfile.self, JobRecord.self,
            configurations: configuration
        )
        let repository = JobRepository(context: container.mainContext)
        let job = try repository.createJob(
            customerName: "Marcus Lee",
            vehicleLabel: "2021 Honda Accord",
            plate: "7HKL248",
            color: "Pearl White",
            serviceName: "Full detail",
            notes: ""
        )
        job.statusRawValue = "unrecognized-status"

        XCTAssertEqual(job.status, .draft)
    }
}

private func completedCaptureDocument(for phase: CapturePhase) -> CaptureDocument {
    CaptureDocument(
        skips: CaptureSlot.standard.map {
            CaptureSkip(slotID: $0.id, phase: phase, reason: "Not accessible")
        }
    )
}
