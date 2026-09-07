import Foundation
import SwiftData
import XCTest
@testable import DetailHandoff

final class SchemaMigrationTests: XCTestCase {
    @MainActor
    func testPhase1DiskStoreMigratesWithoutWipingBaselineRecords() throws {
        let fixtureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DetailHandoff-Phase1-Migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixtureDirectory) }

        let storeURL = fixtureDirectory.appendingPathComponent("DetailHandoff.store")
        let profileID = UUID(uuidString: "6A725CB6-95A8-4E25-A7D2-B157F0ED2A08")!
        let jobID = UUID(uuidString: "0E7FD6C5-98E7-4FA0-9DA1-9EAA54705EF1")!
        let createdAt = Date(timeIntervalSince1970: 1_725_523_200)
        let updatedAt = createdAt.addingTimeInterval(3_600)

        XCTAssertEqual(
            Schema.entityName(for: Phase1DiskSchema.BusinessProfile.self),
            Schema.entityName(for: BusinessProfile.self)
        )
        XCTAssertEqual(
            Schema.entityName(for: Phase1DiskSchema.JobRecord.self),
            Schema.entityName(for: JobRecord.self)
        )

        try autoreleasepool {
            let phase1Container = try ModelContainer(
                for: Phase1DiskSchema.BusinessProfile.self, Phase1DiskSchema.JobRecord.self,
                configurations: ModelConfiguration(url: storeURL)
            )
            let context = phase1Container.mainContext
            context.insert(Phase1DiskSchema.BusinessProfile(
                id: profileID,
                businessName: "Phase 1 Detail",
                phone: "555-0101",
                email: "owner@example.test",
                disclaimer: "Phase 1 disclaimer",
                createdAt: createdAt,
                updatedAt: updatedAt
            ))
            context.insert(Phase1DiskSchema.JobRecord(
                id: jobID,
                customerName: "Morgan",
                vehicleLabel: "Phase 1 Roadster",
                plate: "OLD-101",
                color: "Blue",
                serviceName: "Full detail",
                notes: "Keep this record",
                statusRawValue: JobStatus.beforeCapture.rawValue,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: nil
            ))
            try context.save()
        }

        let migratedContainer = try ModelContainer(
            for: BusinessProfile.self, JobRecord.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        let migratedContext = migratedContainer.mainContext
        let profiles = try migratedContext.fetch(FetchDescriptor<BusinessProfile>())
        let jobs = try migratedContext.fetch(FetchDescriptor<JobRecord>())

        let profile = try XCTUnwrap(profiles.first)
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profile.id, profileID)
        XCTAssertEqual(profile.businessName, "Phase 1 Detail")
        XCTAssertEqual(profile.phone, "555-0101")
        XCTAssertEqual(profile.email, "owner@example.test")
        XCTAssertEqual(profile.disclaimer, "Phase 1 disclaimer")
        XCTAssertEqual(profile.createdAt, createdAt)
        XCTAssertEqual(profile.updatedAt, updatedAt)

        let job = try XCTUnwrap(jobs.first)
        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(job.id, jobID)
        XCTAssertEqual(job.customerName, "Morgan")
        XCTAssertEqual(job.vehicleLabel, "Phase 1 Roadster")
        XCTAssertEqual(job.plate, "OLD-101")
        XCTAssertEqual(job.color, "Blue")
        XCTAssertEqual(job.serviceName, "Full detail")
        XCTAssertEqual(job.notes, "Keep this record")
        XCTAssertEqual(job.status, .beforeCapture)
        XCTAssertEqual(job.createdAt, createdAt)
        XCTAssertEqual(job.updatedAt, updatedAt)
        XCTAssertNil(job.deletedAt)
    }
}

// Exact persisted fields from the Phase 1 baseline at commit e09f85d. This
// creates the old schema on disk before the shipping models open the same URL.
private enum Phase1DiskSchema {
    @Model
    final class BusinessProfile {
        @Attribute(.unique) var id: UUID
        var businessName: String
        var phone: String
        var email: String
        var disclaimer: String
        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID,
            businessName: String,
            phone: String,
            email: String,
            disclaimer: String,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.businessName = businessName
            self.phone = phone
            self.email = email
            self.disclaimer = disclaimer
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class JobRecord {
        @Attribute(.unique) var id: UUID
        var customerName: String
        var vehicleLabel: String
        var plate: String
        var color: String
        var serviceName: String
        var notes: String
        var statusRawValue: String
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?

        init(
            id: UUID,
            customerName: String,
            vehicleLabel: String,
            plate: String,
            color: String,
            serviceName: String,
            notes: String,
            statusRawValue: String,
            createdAt: Date,
            updatedAt: Date,
            deletedAt: Date?
        ) {
            self.id = id
            self.customerName = customerName
            self.vehicleLabel = vehicleLabel
            self.plate = plate
            self.color = color
            self.serviceName = serviceName
            self.notes = notes
            self.statusRawValue = statusRawValue
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }
    }
}
