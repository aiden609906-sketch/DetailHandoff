import SwiftData
import UIKit
import XCTest
@testable import DetailHandoff

final class TrashServiceTests: XCTestCase {
    // Catches early expiry, a strict-greater-than boundary, and repeated deletion extending retention.
    @MainActor
    func testRecoverableAt29DaysAndExpiredAtExactly30Days() throws {
        let f = try TrashFixture()
        defer { f.cleanUp() }
        try f.service.softDelete(f.job)
        let deletedAt = f.clock
        f.clock += 29 * 86400
        try f.service.softDelete(f.job)
        XCTAssertEqual(f.job.deletedAt, deletedAt)
        try f.service.purgeExpired()
        XCTAssertEqual(try f.savedJobs().count, 1)
        try f.service.restore(f.job)
        XCTAssertNil(try XCTUnwrap(f.savedJobs().first).deletedAt)
        XCTAssertEqual(JobRepository(context: f.context).search([f.job], query: "").count, 1)
        try f.service.softDelete(f.job)
        f.clock += 30 * 86400
        XCTAssertThrowsError(try f.service.restore(f.job)) {
            XCTAssertEqual($0 as? TrashServiceError, .expired)
        }
        try f.service.purgeExpired()
        XCTAssertTrue(try f.savedJobs().isEmpty)
        XCTAssertTrue(try f.media.assetInventory().isEmpty)
    }

    // Catches metadata/ledger partial deletion and any physical cleanup before the commit succeeds.
    @MainActor
    func testFailedSavesPreserveMetadataLedgerAndFiles() throws {
        enum Failure: Error, Equatable { case save }
        let f = try TrashFixture()
        defer { f.cleanUp() }
        let originalFiles = try f.files()
        let originalTimestamp = f.job.updatedAt
        let failing = TrashService(context: f.context, media: f.media, now: { f.clock }, saveChanges: { throw Failure.save })
        XCTAssertThrowsError(try failing.softDelete(f.job)) { XCTAssertEqual($0 as? Failure, .save) }
        XCTAssertNil(f.job.deletedAt)
        XCTAssertEqual(f.job.updatedAt, originalTimestamp)
        XCTAssertTrue(f.job.modelContext === f.context)
        XCTAssertFalse(f.context.hasChanges)
        XCTAssertNil(try XCTUnwrap(f.savedJobs().first).deletedAt)
        _ = try f.seal()
        f.profile.reportNumberLedgerData = nil
        try f.context.save()
        try f.service.softDelete(f.job)
        XCTAssertThrowsError(try failing.restore(f.job))
        XCTAssertNotNil(f.job.deletedAt)
        let withReport = try f.files()
        XCTAssertThrowsError(try failing.permanentlyDelete(f.job))
        XCTAssertEqual(try f.files(), withReport)
        XCTAssertEqual(try f.savedJobs().count, 1)
        let fresh = ModelContext(f.container)
        XCTAssertNil(try XCTUnwrap(fresh.fetch(FetchDescriptor<BusinessProfile>()).first).reportNumberLedgerData)
        XCTAssertTrue(originalFiles.keys.allSatisfy { withReport[$0] == originalFiles[$0] })
    }

    // Catches cached restore mutations surviving rollback, independently of a prior soft-delete failure.
    @MainActor
    func testFailedRestorePreservesCachedAndSavedDeletionStateAndCanRetry() throws {
        enum Failure: Error, Equatable { case save }
        let f = try TrashFixture()
        defer { f.cleanUp() }
        try f.service.softDelete(f.job)
        let deletedAt = f.job.deletedAt
        let updatedAt = f.job.updatedAt
        let files = try f.files()
        f.clock += 86400
        let failing = TrashService(context: f.context, media: f.media, now: { f.clock }, saveChanges: { throw Failure.save })

        XCTAssertThrowsError(try failing.restore(f.job)) { XCTAssertEqual($0 as? Failure, .save) }

        XCTAssertEqual(f.job.deletedAt, deletedAt)
        XCTAssertEqual(f.job.updatedAt, updatedAt)
        XCTAssertTrue(f.job.modelContext === f.context)
        XCTAssertFalse(f.job.isDeleted)
        XCTAssertFalse(f.context.hasChanges)
        let saved = try XCTUnwrap(f.savedJobs().first)
        XCTAssertEqual(saved.deletedAt, deletedAt)
        XCTAssertEqual(saved.updatedAt, updatedAt)
        XCTAssertEqual(try f.files(), files)
        try f.service.restore(f.job)
        XCTAssertNil(f.job.deletedAt)
        XCTAssertNil(try XCTUnwrap(f.savedJobs().first).deletedAt)
    }

    // Catches cached ledger changes or pending deletion surviving a failed purge, without a preceding failure.
    @MainActor
    func testFailedPurgePreservesCachedLedgerAndJobAndCanRetry() throws {
        enum Failure: Error, Equatable { case save }
        let f = try TrashFixture()
        defer { f.cleanUp() }
        let report = try f.seal()
        f.profile.reportNumberLedgerData = nil
        try f.context.save()
        try f.service.softDelete(f.job)
        let deletedAt = f.job.deletedAt
        let reports = f.job.reportsData
        let files = try f.files()
        let failing = TrashService(context: f.context, media: f.media, now: { f.clock }, saveChanges: { throw Failure.save })

        XCTAssertThrowsError(try failing.permanentlyDelete(f.job)) { XCTAssertEqual($0 as? Failure, .save) }

        XCTAssertTrue(f.job.modelContext === f.context)
        XCTAssertFalse(f.job.isDeleted)
        XCTAssertEqual(f.job.deletedAt, deletedAt)
        XCTAssertEqual(f.job.reportsData, reports)
        XCTAssertTrue(f.profile.modelContext === f.context)
        XCTAssertNil(f.profile.reportNumberLedgerData)
        XCTAssertFalse(f.context.hasChanges)
        let fresh = ModelContext(f.container)
        let saved = try XCTUnwrap(fresh.fetch(FetchDescriptor<JobRecord>()).first)
        XCTAssertEqual(saved.deletedAt, deletedAt)
        XCTAssertEqual(saved.reportsData, reports)
        XCTAssertNil(try XCTUnwrap(fresh.fetch(FetchDescriptor<BusinessProfile>()).first).reportNumberLedgerData)
        XCTAssertEqual(try f.files(), files)
        try f.service.permanentlyDelete(f.job)
        XCTAssertTrue(try f.savedJobs().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: try f.media.url(for: report.pdfPath).path))
        XCTAssertEqual(try ReportNumberLedger.decode(f.profile.reportNumberLedgerData).highWaterByDay, ["20260904": 1])
    }

    // Catches deleting original/thumbnail/PDF/logo assets still referenced by a different retained row.
    @MainActor
    func testPurgeProtectsSharedAndFrozenAssetsThenReclaimsAfterLastOwner() throws {
        let f = try TrashFixture()
        defer { f.cleanUp() }
        let report = try f.seal()
        let other = f.makeJob()
        var sharedReport = report
        sharedReport.snapshot.jobID = other.id
        other.reportsData = try JSONEncoder().encode([sharedReport])
        other.captureData = f.job.captureData
        f.context.insert(other)
        try f.context.save()
        let all = try f.files()
        try f.service.softDelete(f.job)
        try f.service.permanentlyDelete(f.job)
        XCTAssertEqual(try f.files(), all)
        try f.service.softDelete(other)
        try f.service.permanentlyDelete(other)
        XCTAssertTrue(try f.media.assetInventory().isEmpty)
    }

    // Catches a nil legacy ledger allowing a previously issued number to be reused after purge.
    @MainActor
    func testPurgeFloorsLegacyReportNumberInSameSave() throws {
        let f = try TrashFixture()
        defer { f.cleanUp() }
        var report = try f.seal()
        report.reportNumber = "DH-20260904-0042"
        f.job.reportsData = try JSONEncoder().encode([report])
        f.profile.reportNumberLedgerData = nil
        try f.context.save()
        try f.service.softDelete(f.job)
        try f.service.permanentlyDelete(f.job)
        let fresh = ModelContext(f.container)
        let profile = try XCTUnwrap(fresh.fetch(FetchDescriptor<BusinessProfile>()).first)
        XCTAssertEqual(try ReportNumberLedger.decode(profile.reportNumberLedgerData).highWaterByDay, ["20260904": 42])
        let next = f.makeJob()
        f.context.insert(next)
        try f.prepareForSeal(next)
        XCTAssertEqual(try f.reportRepository.seal(job: next, business: f.profile).reportNumber, "DH-20260904-0043")
    }

    // Catches undercounting unlink/restore leftovers and cleanup removing frozen-only evidence or branding.
    @MainActor
    func testStorageCountsAllFilesAndConfirmedCleanupRetainsEveryReference() throws {
        let f = try TrashFixture()
        defer { f.cleanUp() }
        // Simulate the flat shared namespace created by backup restore without guessing ownership.
        var restoredPhoto = f.photo
        restoredPhoto.imagePath = "Restores/shared/frozen.jpg"
        restoredPhoto.thumbnailPath = "Restores/shared/frozen-thumb.jpg"
        try f.write(f.media.readRegularAsset(at: f.photo.imagePath), at: restoredPhoto.imagePath)
        try f.write(f.media.readRegularAsset(at: f.photo.thumbnailPath), at: restoredPhoto.thumbnailPath)
        f.job.captureData = try JSONEncoder().encode(CaptureDocument(photos: [restoredPhoto]))
        try f.context.save()
        let frozenReport = try f.seal()
        try f.reportRepository.beginRevision(job: f.job)
        let capture = CaptureRepository(context: f.context, media: f.media)
        try capture.removePhoto(from: f.job, photoID: f.photo.id)
        let orphan = try f.media.storeImage(TrashFixture.image(), jobID: f.job.id)
        let restoredOrphan = "Restores/old/previous.jpg"
        try f.write(TrashFixture.image(), at: restoredOrphan)
        let currentLogo = "Restores/shared/current-logo.jpg"
        try f.write(TrashFixture.image(), at: currentLogo)
        f.profile.logoImagePath = currentLogo
        try f.context.save()
        let before = try f.files()
        let orphanPaths = [orphan.imagePath, orphan.thumbnailPath, restoredOrphan, f.photo.imagePath, f.photo.thumbnailPath]
        let summary = try f.service.storageSummary()
        XCTAssertEqual(summary.totalBytes, Int64(before.values.reduce(0) { $0 + $1.count }))
        XCTAssertEqual(summary.reclaimableBytes, Int64(orphanPaths.reduce(0) { $0 + (before[$1]?.count ?? 0) }))
        XCTAssertEqual(summary.jobs.count, 1)
        let jobPaths = [f.photo.imagePath, f.photo.thumbnailPath, restoredPhoto.imagePath, restoredPhoto.thumbnailPath, frozenReport.pdfPath, orphan.imagePath, orphan.thumbnailPath]
        XCTAssertEqual(summary.jobs[0].bytes, Int64(jobPaths.reduce(0) { $0 + (before[$1]?.count ?? 0) }))
        try f.service.cleanOrphans()
        let after = try f.files()
        XCTAssertEqual(Set(after.keys), Set(before.keys).subtracting(orphanPaths))
        XCTAssertEqual(after[restoredPhoto.imagePath], before[restoredPhoto.imagePath])
        XCTAssertEqual(after[restoredPhoto.thumbnailPath], before[restoredPhoto.thumbnailPath])
        XCTAssertEqual(after[currentLogo], before[currentLogo])
        XCTAssertEqual(try f.service.storageSummary().reclaimableBytes, 0)
    }

    // Catches cleanup failure being swallowed or permanently losing the ability to reclaim leaked files.
    @MainActor
    func testCleanupFailureIsVisibleAndRetryRechecksReferences() throws {
        enum Failure: Error { case remove }
        let f = try TrashFixture()
        defer { f.cleanUp() }
        try f.service.softDelete(f.job)
        let prior = try f.files()
        let failing = TrashService(context: f.context, media: f.media, now: { f.clock }, removeAsset: { _ in throw Failure.remove })
        XCTAssertThrowsError(try failing.permanentlyDelete(f.job)) {
            guard let error = $0 as? TrashServiceError, case .cleanupIncomplete = error else { return XCTFail("Missing retryable cleanup error") }
        }
        XCTAssertTrue(try f.savedJobs().isEmpty)
        XCTAssertEqual(try f.files(), prior)
        // A later import may reference one of these files. Retry must not use a stale deletion list.
        f.profile.logoImagePath = f.photo.imagePath
        try f.context.save()
        try f.service.cleanOrphans()
        XCTAssertEqual(Set(try f.files().keys), [f.photo.imagePath])
    }

    // Catches path traversal in imported records, symlink traversal, and malformed metadata fail-open.
    @MainActor
    func testUnsafeOrUnreadableGraphBlocksCleanupWithoutDeletingAnything() throws {
        for mode in ["traversal", "symlink", "corrupt", "missing"] {
            let f = try TrashFixture()
            defer { f.cleanUp() }
            let outside = f.root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: outside) }
            let sentinel = Data("Must survive".utf8)
            try sentinel.write(to: outside)
            if mode == "traversal" {
                var capture = try CaptureRepository(context: f.context, media: f.media).document(for: f.job)
                capture.photos[0].imagePath = "../\(outside.lastPathComponent)"
                f.job.captureData = try JSONEncoder().encode(capture)
            } else if mode == "symlink" {
                try FileManager.default.createSymbolicLink(at: f.root.appendingPathComponent("linked"), withDestinationURL: outside)
                XCTAssertThrowsError(try f.media.removeRegularAsset(at: "linked"))
            } else if mode == "corrupt" {
                f.job.reportsData = Data([0xFF])
            } else {
                try FileManager.default.removeItem(at: f.media.url(for: f.photo.imagePath))
            }
            try f.context.save()
            try f.service.softDelete(f.job)
            XCTAssertThrowsError(try f.service.permanentlyDelete(f.job), mode)
            XCTAssertThrowsError(try f.service.cleanOrphans(), mode)
            XCTAssertEqual(try f.savedJobs().count, 1)
            XCTAssertEqual(try Data(contentsOf: outside), sentinel)
            XCTAssertTrue(FileManager.default.fileExists(atPath: try f.media.url(for: f.photo.thumbnailPath).path))
        }
    }

    // Catches automatically wiping undecodable retained files and purging jobs before retention expires.
    @MainActor
    func testAutomaticPurgePreservesUnreadableOwnedAssetsAndUnrelatedOrphans() throws {
        let f = try TrashFixture()
        defer { f.cleanUp() }
        let unlinked = "\(f.job.id.uuidString)/damaged.jpg"
        try f.write(Data([1, 2, 3]), at: unlinked)
        try f.write(TrashFixture.image(), at: "Restores/previous/leftover.jpg")
        try f.service.softDelete(f.job)
        f.clock += 30 * 86400
        let prior = try f.files()
        XCTAssertThrowsError(try f.service.purgeExpired())
        XCTAssertEqual(try f.files(), prior)
        XCTAssertEqual(try f.savedJobs().count, 1)
    }

    // Catches probing a declared report as an image and silently accepting the wrong evidence kind.
    @MainActor
    func testAutomaticPurgeDoesNotAcceptAnImageDisguisedAsPDF() throws {
        let f = try TrashFixture()
        defer { f.cleanUp() }
        let path = "Reports/\(f.job.id.uuidString)/damaged.pdf"
        try f.write(TrashFixture.image(), at: path)
        try f.service.softDelete(f.job)
        f.clock += 30 * 86400
        let files = try f.files()

        XCTAssertThrowsError(try f.service.purgeExpired()) {
            XCTAssertEqual($0 as? TrashServiceError, .unreadableAsset(path))
        }

        XCTAssertEqual(try f.savedJobs().count, 1)
        XCTAssertEqual(try f.files(), files)
    }

    // Catches a job purge leaking unlinked image pairs or indiscriminately deleting other orphan folders.
    @MainActor
    func testAutomaticPurgeRemovesOwnedUnlinkedFilesButNotUnrelatedOrphans() throws {
        let f = try TrashFixture()
        defer { f.cleanUp() }
        try CaptureRepository(context: f.context, media: f.media).removePhoto(from: f.job, photoID: f.photo.id)
        let orphanPath = "Restores/previous/leftover.jpg"
        let orphanBytes = TrashFixture.image()
        try f.write(orphanBytes, at: orphanPath)
        try f.service.softDelete(f.job)
        f.clock += 30 * 86400 - 1
        try f.service.purgeExpired()
        XCTAssertEqual(try f.savedJobs().count, 1)
        XCTAssertEqual(try f.media.assetInventory().count, 3)
        f.clock += 1
        try f.service.purgeExpired()
        XCTAssertTrue(try f.savedJobs().isEmpty)
        XCTAssertEqual(try f.files(), [orphanPath: orphanBytes])
    }

    // Catches cleanup deleting references held only by retained trash, and unsaved editor changes being rolled back.
    @MainActor
    func testTrashReferencesRemainProtectedAndPendingChangesBlockDestruction() throws {
        let f = try TrashFixture()
        defer { f.cleanUp() }
        try f.service.softDelete(f.job)
        let prior = try f.files()
        try f.service.cleanOrphans()
        XCTAssertEqual(try f.files(), prior)
        XCTAssertEqual(try f.service.storageSummary().reclaimableBytes, 0)
        f.profile.businessName = "Unsaved edit"
        XCTAssertThrowsError(try f.service.permanentlyDelete(f.job)) {
            XCTAssertEqual($0 as? TrashServiceError, .unsavedChanges)
        }
        XCTAssertEqual(f.profile.businessName, "Unsaved edit")
        XCTAssertEqual(try f.savedJobs().count, 1)
        XCTAssertEqual(try f.files(), prior)
    }

    // Catches fresh-install launch crashes and silently discarding legacy numbers without a profile.
    @MainActor
    func testStartupWithoutProfileIsSafeAndLegacyHistoryFailsClosed() throws {
        let f = try TrashFixture()
        defer { f.cleanUp() }
        _ = try f.seal()
        f.context.delete(f.profile)
        try f.context.save()
        try f.service.purgeExpired()
        try f.service.softDelete(f.job)
        f.clock += 30 * 86400
        XCTAssertThrowsError(try f.service.purgeExpired())
        XCTAssertEqual(try f.savedJobs().count, 1)
        let empty = try ModelContainer(for: BusinessProfile.self, JobRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        try TrashService(context: empty.mainContext, media: f.media).purgeExpired()
    }

    // Catches old editors, direct camera callbacks and suspended picker loads mutating a trashed record.
    @MainActor
    func testDeletedJobsRejectEditsAndInvalidateSuspendedImports() async throws {
        let f = try TrashFixture()
        defer { f.cleanUp() }
        var continuation: CheckedContinuation<Data?, Never>?
        let task = Task { @MainActor in
            try await EvidenceImport.loadAndSave(load: {
                await withCheckedContinuation { continuation = $0 }
            }, save: { data in
                try CaptureRepository(context: f.context, media: f.media).addPhoto(to: f.job, data: data, slotID: "front", phase: .before)
            })
        }
        while continuation == nil { await Task.yield() }
        try f.service.softDelete(f.job)
        let prior = try f.files()
        continuation?.resume(returning: TrashFixture.image())
        do { try await task.value; XCTFail("Deleted import saved") }
        catch { XCTAssertTrue(error is CancellationError) }
        let capture = CaptureRepository(context: f.context, media: f.media)
        XCTAssertThrowsError(try capture.addPhoto(to: f.job, data: TrashFixture.image(), slotID: "front", phase: .before))
        XCTAssertThrowsError(try JobRepository(context: f.context).advance(f.job))
        XCTAssertThrowsError(try JobRepository(context: f.context).updateDetails(f.job, customerName: "Changed", customerPhone: nil, customerEmail: nil, vehicleLabel: "Car", plate: "", color: "", serviceName: "Wash", location: nil, notes: ""))
        XCTAssertThrowsError(try AcknowledgmentRepository(context: f.context).markUnavailable(job: f.job, reason: "Absent"))
        XCTAssertEqual(try f.files(), prior)
        XCTAssertEqual(try XCTUnwrap(f.savedJobs().first).customerName, "Customer")
        try f.service.permanentlyDelete(f.job)
        XCTAssertThrowsError(try capture.addPhoto(to: f.job, data: TrashFixture.image(), slotID: "front", phase: .before))
        XCTAssertTrue(try f.savedJobs().isEmpty)
        XCTAssertTrue(try f.media.assetInventory().isEmpty)
    }
}

@MainActor
private final class TrashFixture {
    let container: ModelContainer
    let root: URL
    let media: MediaStore
    let job: JobRecord
    let profile: BusinessProfile
    let photo: CapturedPhoto
    var clock = Date(timeIntervalSince1970: 1_788_480_000)
    var context: ModelContext { container.mainContext }
    var service: TrashService { TrashService(context: context, media: media, now: { self.clock }) }
    var reportRepository: ReportRepository {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return ReportRepository(context: context, media: media, now: { self.clock }, calendar: calendar)
    }

    init() throws {
        container = try ModelContainer(for: BusinessProfile.self, JobRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        container.mainContext.autosaveEnabled = false
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        media = MediaStore(root: root)
        job = JobRecord(customerName: "Customer", vehicleLabel: "Car", plate: "ABC", color: "Blue", serviceName: "Wash", notes: "")
        profile = BusinessProfile(businessName: "Detailer")
        let stored = try media.storeImage(Self.image(), jobID: job.id)
        photo = CapturedPhoto(slotID: "front", phase: .before, imagePath: stored.imagePath, thumbnailPath: stored.thumbnailPath)
        job.captureData = try JSONEncoder().encode(CaptureDocument(photos: [photo]))
        context.insert(job)
        context.insert(profile)
        try context.save()
    }

    func makeJob() -> JobRecord {
        JobRecord(customerName: "Other", vehicleLabel: "Other car", plate: "DEF", color: "White", serviceName: "Wash", notes: "")
    }

    func prepareForSeal(_ target: JobRecord) throws {
        var capture = try CaptureRepository(context: context, media: media).document(for: target)
        capture.skips = CapturePhase.allCases.flatMap { phase in CaptureSlot.standard.map { CaptureSkip(slotID: $0.id, phase: phase, reason: "Not accessible") } }
        target.captureData = try JSONEncoder().encode(capture)
        target.status = .review
        try AcknowledgmentRepository(context: context).markUnavailable(job: target, reason: "Absent")
    }

    func seal() throws -> ReportVersion {
        try prepareForSeal(job)
        return try reportRepository.seal(job: job, business: profile)
    }

    func savedJobs() throws -> [JobRecord] { try ModelContext(container).fetch(FetchDescriptor<JobRecord>()) }
    func files() throws -> [String: Data] {
        // Independent filesystem oracle: an inventory regression must not alter our expected bytes.
        let entries = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])?.allObjects as? [URL] ?? []
        var result: [String: Data] = [:]
        for entry in entries {
            let values = try entry.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isRegularFile == true, values.isSymbolicLink != true {
                result[String(entry.path.dropFirst(root.path.count + 1))] = try Data(contentsOf: entry)
            }
        }
        return result
    }
    func write(_ data: Data, at path: String) throws {
        let url = try media.url(for: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
    static func image() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).jpegData(withCompressionQuality: 0.9) { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
    }
    func cleanUp() { try? FileManager.default.removeItem(at: root) }
}
