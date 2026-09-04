import CryptoKit
import SwiftData
import XCTest
@testable import DetailHandoff

final class AcknowledgmentRepositoryTests: XCTestCase {
    @MainActor
    func testSignRejectsBlankNameAndTapOnlyOrOutOfRangeStrokes() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let repository = AcknowledgmentRepository(context: container.mainContext)

        XCTAssertThrowsError(try repository.sign(job: job, name: "   ", strokes: validStrokes())) { error in
            XCTAssertEqual(error as? AcknowledgmentRepositoryError, .blankCustomerName)
        }
        XCTAssertThrowsError(try repository.sign(job: job, name: "Marcus", strokes: [])) { error in
            XCTAssertEqual(error as? AcknowledgmentRepositoryError, .emptySignature)
        }
        XCTAssertThrowsError(try repository.sign(job: job, name: "Marcus", strokes: [SignatureStroke(points: [SignaturePoint(x: 0.5, y: 0.5)])])) { error in
            XCTAssertEqual(error as? AcknowledgmentRepositoryError, .emptySignature)
        }
        XCTAssertThrowsError(try repository.sign(job: job, name: "Marcus", strokes: [SignatureStroke(points: [SignaturePoint(x: 0.2, y: 0.2), SignaturePoint(x: 1.1, y: 0.3)])])) { error in
            XCTAssertEqual(error as? AcknowledgmentRepositoryError, .invalidSignaturePoint)
        }
    }

    @MainActor
    func testMarkUnavailableRejectsBlankReason() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)

        XCTAssertThrowsError(try AcknowledgmentRepository(context: container.mainContext).markUnavailable(job: job, reason: " \n ")) { error in
            XCTAssertEqual(error as? AcknowledgmentRepositoryError, .blankUnavailableReason)
        }
        XCTAssertNil(job.acknowledgmentData)
    }

    @MainActor
    func testSignPersistsNormalizedMultisegmentSignatureThroughFreshContext() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let jobID = job.id
        let repository = AcknowledgmentRepository(context: container.mainContext)

        try repository.sign(job: job, name: "  Marcus Lee  ", strokes: validStrokes())

        let freshContext = ModelContext(container)
        let savedJob = try XCTUnwrap(try freshContext.fetch(FetchDescriptor<JobRecord>(predicate: #Predicate { $0.id == jobID })).first)
        let record = try XCTUnwrap(try AcknowledgmentRepository(context: freshContext).record(for: savedJob))
        XCTAssertEqual(record.method, .signature)
        XCTAssertEqual(record.customerName, "Marcus Lee")
        XCTAssertEqual(record.strokes, validStrokes())
        XCTAssertEqual(record.unavailableReason, "")
        XCTAssertEqual(record.confirmationText, AcknowledgmentRecord.confirmationText)
        XCTAssertFalse(record.contentDigest.isEmpty)
    }

    @MainActor
    func testAcknowledgmentIsNotCurrentWhenCopiedToDifferentJobOrBeforeContentChanges() throws {
        let container = try makeContainer()
        let firstJob = try makeSavedJob(in: container)
        let secondJob = try makeSavedJob(in: container)
        firstJob.captureData = try JSONEncoder().encode(beforeCompleteDocument())
        secondJob.captureData = try JSONEncoder().encode(beforeCompleteDocument())
        let repository = AcknowledgmentRepository(context: container.mainContext)

        try repository.sign(job: firstJob, name: "Marcus Lee", strokes: validStrokes())
        XCTAssertTrue(try repository.isCurrent(job: firstJob))

        secondJob.acknowledgmentData = firstJob.acknowledgmentData
        XCTAssertFalse(try repository.isCurrent(job: secondJob))

        var changedDocument = beforeCompleteDocument()
        changedDocument.skips[0].reason = "Customer asked to leave this view covered"
        firstJob.captureData = try JSONEncoder().encode(changedDocument)
        XCTAssertFalse(try repository.isCurrent(job: firstJob))
    }

    @MainActor
    func testAcknowledgmentRemainsCurrentWhenOnlyAfterPhotoChanges() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        var document = beforeCompleteDocument()
        document.photos.append(CapturedPhoto(
            slotID: "front",
            phase: .after,
            imagePath: "\(job.id.uuidString)/after.jpg",
            thumbnailPath: "\(job.id.uuidString)/after-thumb.jpg"
        ))
        job.captureData = try JSONEncoder().encode(document)
        let repository = AcknowledgmentRepository(context: container.mainContext)

        try repository.markUnavailable(job: job, reason: "Customer left keys with the office")

        XCTAssertTrue(try repository.isCurrent(job: job))
    }

    @MainActor
    func testAcknowledgmentDigestPreservesLegacyNilContactsAndBecomesStaleWhenContactChanges() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let repository = AcknowledgmentRepository(context: container.mainContext)
        let legacyPayload = LegacyPreServiceContent(
            jobID: job.id.uuidString,
            customerName: job.customerName,
            vehicleLabel: job.vehicleLabel,
            plate: job.plate,
            color: job.color,
            serviceName: job.serviceName,
            beforePhotos: [],
            beforeSkips: [],
            findings: []
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let digest = SHA256.hash(data: try encoder.encode(legacyPayload)).map { String(format: "%02x", $0) }.joined()
        job.acknowledgmentData = try JSONEncoder().encode(AcknowledgmentRecord(
            method: .customerUnavailable,
            customerName: job.customerName,
            recordedAt: .now,
            confirmationText: AcknowledgmentRecord.confirmationText,
            unavailableReason: "Customer left keys with the office",
            strokes: [],
            contentDigest: digest
        ))

        XCTAssertTrue(try repository.isCurrent(job: job))

        job.customerPhone = "555-0123"
        XCTAssertFalse(try repository.isCurrent(job: job))
    }

    @MainActor
    func testFailedSaveRestoresAcknowledgmentPayloadAndTimestamp() throws {
        enum SaveFailure: Error { case simulated }

        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let oldTimestamp = Date(timeIntervalSince1970: 1)
        job.updatedAt = oldTimestamp
        let repository = AcknowledgmentRepository(context: container.mainContext) { throw SaveFailure.simulated }

        XCTAssertThrowsError(try repository.markUnavailable(job: job, reason: "Customer is unavailable"))
        XCTAssertNil(job.acknowledgmentData)
        XCTAssertEqual(job.updatedAt, oldTimestamp)
    }

    @MainActor
    func testFailedSaveRestoresExistingAcknowledgmentPayloadAndTimestamp() throws {
        enum SaveFailure: Error { case simulated }

        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        try AcknowledgmentRepository(context: container.mainContext).markUnavailable(
            job: job,
            reason: "Customer left keys with the office"
        )
        let previousData = try XCTUnwrap(job.acknowledgmentData)
        let oldTimestamp = Date(timeIntervalSince1970: 1)
        job.updatedAt = oldTimestamp
        let repository = AcknowledgmentRepository(context: container.mainContext) { throw SaveFailure.simulated }

        XCTAssertThrowsError(try repository.markUnavailable(job: job, reason: "Customer is unavailable"))
        XCTAssertEqual(job.acknowledgmentData, previousData)
        XCTAssertEqual(job.updatedAt, oldTimestamp)
    }

    @MainActor
    func testRecordRejectsCorruptStoredPayload() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        job.acknowledgmentData = Data([0xFF])

        XCTAssertThrowsError(try AcknowledgmentRepository(context: container.mainContext).record(for: job)) { error in
            XCTAssertEqual(error as? AcknowledgmentRepositoryError, .corruptRecord)
        }
    }

    private func validStrokes() -> [SignatureStroke] {
        [
            SignatureStroke(points: [SignaturePoint(x: 0.10, y: 0.15), SignaturePoint(x: 0.35, y: 0.40)]),
            SignatureStroke(points: [SignaturePoint(x: 0.55, y: 0.30), SignaturePoint(x: 0.82, y: 0.70)])
        ]
    }

    private func beforeCompleteDocument() -> CaptureDocument {
        CaptureDocument(skips: CaptureSlot.standard.map {
            CaptureSkip(slotID: $0.id, phase: .before, reason: "Not accessible")
        })
    }
}

private struct LegacyPreServiceContent: Codable {
    var jobID: String
    var customerName: String
    var vehicleLabel: String
    var plate: String
    var color: String
    var serviceName: String
    var beforePhotos: [String]
    var beforeSkips: [String]
    var findings: [String]
}
