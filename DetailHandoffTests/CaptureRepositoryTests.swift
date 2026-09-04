import SwiftData
import UIKit
import XCTest
@testable import DetailHandoff

final class CaptureRepositoryTests: XCTestCase {
    private var root: URL!

    override func setUp() { super.setUp(); root = makeTemporaryRoot() }
    override func tearDown() { try? FileManager.default.removeItem(at: root); super.tearDown() }

    @MainActor
    func testAddPhotoPersistsDocumentAndMediaAcrossFreshContext() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let repository = CaptureRepository(context: container.mainContext, media: MediaStore(root: root))
        try repository.addPhoto(to: job, data: try jpegData(), slotID: "front", phase: .before)
        let added = try XCTUnwrap(try repository.document(for: job).photos.first)
        let reloadedContext = ModelContext(container)
        let savedJob = try fetchJob(addedTo: reloadedContext, id: job.id)
        let reloaded = try CaptureRepository(context: reloadedContext, media: MediaStore(root: root)).document(for: savedJob)
        XCTAssertEqual(reloaded.photos, [added])
        XCTAssertTrue(FileManager.default.fileExists(atPath: try MediaStore(root: root).url(for: added.imagePath).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try MediaStore(root: root).url(for: added.thumbnailPath).path))
    }

    @MainActor
    func testInvalidPhotoLeavesMetadataAndMediaUnchanged() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let repository = CaptureRepository(context: container.mainContext, media: MediaStore(root: root))
        XCTAssertThrowsError(try repository.addPhoto(to: job, data: Data([0xFF]), slotID: "front", phase: .before))
        XCTAssertEqual(try repository.document(for: job), .empty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    @MainActor
    func testAddPhotoRejectsUnknownSlotAndFinalizedJob() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let repository = CaptureRepository(context: container.mainContext, media: MediaStore(root: root))
        XCTAssertThrowsError(try repository.addPhoto(to: job, data: try jpegData(), slotID: "unknown", phase: .before))
        job.status = .finalized
        XCTAssertThrowsError(try repository.addPhoto(to: job, data: try jpegData(), slotID: "front", phase: .before))
        job.status = .archived
        XCTAssertThrowsError(try repository.addPhoto(to: job, data: try jpegData(), slotID: "front", phase: .before))
    }

    @MainActor
    func testRequiredSkipRejectsWhitespaceAndCanBeCleared() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let repository = CaptureRepository(context: container.mainContext, media: MediaStore(root: root))
        XCTAssertThrowsError(try repository.setSkip(on: job, slotID: "front", phase: .before, reason: " \n "))
        try repository.setSkip(on: job, slotID: "front", phase: .before, reason: " Vehicle blocked ")
        XCTAssertEqual(try repository.document(for: job).skips, [CaptureSkip(slotID: "front", phase: .before, reason: "Vehicle blocked")])
        try repository.clearSkip(on: job, slotID: "front", phase: .before)
        XCTAssertTrue(try repository.document(for: job).skips.isEmpty)
    }

    @MainActor
    func testFindingRequiresOwnedSlotPhotoAndBlocksLinkedPhotoDeletion() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let repository = CaptureRepository(context: container.mainContext, media: MediaStore(root: root))
        try repository.addPhoto(to: job, data: try jpegData(), slotID: "front", phase: .before)
        let photo = try XCTUnwrap(try repository.document(for: job).photos.first)
        let wrongSlotFinding = VehicleFinding(slotID: "rear", kind: "Scratch", severity: "Low", notes: "", photoIDs: [photo.id])
        XCTAssertThrowsError(try repository.saveFinding(on: job, finding: wrongSlotFinding))
        let finding = VehicleFinding(slotID: "front", kind: "Scratch", severity: "Low", notes: "", photoIDs: [photo.id])
        try repository.saveFinding(on: job, finding: finding)
        XCTAssertThrowsError(try repository.removePhoto(from: job, photoID: photo.id))
        try repository.removeFinding(from: job, findingID: finding.id)
        try repository.removePhoto(from: job, photoID: photo.id)
        XCTAssertTrue(try repository.document(for: job).photos.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try MediaStore(root: root).url(for: photo.imagePath).path))
    }

    @MainActor
    func testRemovePhotoUnlinksMetadataButRetainsEvidenceFilesAcrossFreshContext() throws {
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let repository = CaptureRepository(context: container.mainContext, media: MediaStore(root: root))
        let store = MediaStore(root: root)
        try repository.addPhoto(to: job, data: try jpegData(), slotID: "front", phase: .before)
        let photo = try XCTUnwrap(try repository.document(for: job).photos.first)

        try repository.removePhoto(from: job, photoID: photo.id)
        let reloadedContext = ModelContext(container)
        let reloadedJob = try fetchJob(addedTo: reloadedContext, id: job.id)

        XCTAssertTrue(try CaptureRepository(context: reloadedContext, media: store).document(for: reloadedJob).photos.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try store.url(for: photo.imagePath).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try store.url(for: photo.thumbnailPath).path))
    }

    @MainActor
    func testRemovePhotoFailedSavePreservesMetadataTimestampAndEvidenceFiles() throws {
        enum SaveFailure: Error, Equatable { case simulated }

        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let store = MediaStore(root: root)
        let writer = CaptureRepository(context: container.mainContext, media: store)
        try writer.addPhoto(to: job, data: try jpegData(), slotID: "front", phase: .before)
        let photo = try XCTUnwrap(try writer.document(for: job).photos.first)
        let originalData = job.captureData
        let originalTimestamp = job.updatedAt
        let repository = CaptureRepository(context: container.mainContext, media: store) { throw SaveFailure.simulated }

        XCTAssertThrowsError(try repository.removePhoto(from: job, photoID: photo.id)) { error in
            XCTAssertEqual(error as? SaveFailure, .simulated)
        }
        XCTAssertEqual(job.captureData, originalData)
        XCTAssertEqual(job.updatedAt, originalTimestamp)
        XCTAssertEqual(try repository.document(for: job).photos, [photo])
        XCTAssertTrue(FileManager.default.fileExists(atPath: try store.url(for: photo.imagePath).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try store.url(for: photo.thumbnailPath).path))
    }

    @MainActor
    func testAddPhotoSurfacesSaveAndCleanupErrorsWithoutChangingMetadata() throws {
        enum SaveFailure: Error, Equatable { case simulated }
        enum CleanupFailure: Error, Equatable { case simulated }

        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let originalTimestamp = job.updatedAt
        var uncommittedImage: StoredImage?
        let repository = CaptureRepository(
            context: container.mainContext,
            media: MediaStore(root: root),
            saveChanges: { throw SaveFailure.simulated },
            removeStoredImage: { image in
                uncommittedImage = image
                throw CleanupFailure.simulated
            }
        )

        XCTAssertThrowsError(try repository.addPhoto(to: job, data: try jpegData(), slotID: "front", phase: .before)) { error in
            let rollback = error as? CaptureRepositoryRollbackError
            XCTAssertEqual(rollback?.saveError as? SaveFailure, .simulated)
            XCTAssertEqual(rollback?.cleanupError as? CleanupFailure, .simulated)
        }
        XCTAssertNil(job.captureData)
        XCTAssertEqual(job.updatedAt, originalTimestamp)
        let stored = try XCTUnwrap(uncommittedImage)
        let store = MediaStore(root: root)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try store.url(for: stored.imagePath).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try store.url(for: stored.thumbnailPath).path))
    }

    @MainActor
    func testFailedSavePreservesOriginalErrorMetadataTimestampAndNewFilesAreRemoved() throws {
        enum SaveFailure: Error, Equatable { case simulated }
        let container = try makeContainer()
        let job = try makeSavedJob(in: container)
        let originalTimestamp = job.updatedAt
        let repository = CaptureRepository(context: container.mainContext, media: MediaStore(root: root)) { throw SaveFailure.simulated }
        XCTAssertThrowsError(try repository.addPhoto(to: job, data: try jpegData(), slotID: "front", phase: .before)) { error in
            XCTAssertEqual(error as? SaveFailure, .simulated)
        }
        XCTAssertNil(job.captureData)
        XCTAssertEqual(job.updatedAt, originalTimestamp)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    private func jpegData() throws -> Data {
        try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 32, height: 24)).jpegData(withCompressionQuality: 0.9) { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
        })
    }

    @MainActor
    private func fetchJob(addedTo context: ModelContext, id: UUID) throws -> JobRecord {
        try XCTUnwrap(try context.fetch(FetchDescriptor<JobRecord>(predicate: #Predicate { $0.id == id })).first)
    }
}
