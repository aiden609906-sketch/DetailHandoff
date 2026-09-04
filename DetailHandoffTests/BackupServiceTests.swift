import CryptoKit
import SwiftData
import UIKit
import XCTest
@testable import DetailHandoff

final class BackupServiceTests: XCTestCase {
    // Catches omitted nullable metadata, trash, frozen originals and storage-only signature invalidation.
    @MainActor
    func testRoundTripRestoresAllFieldsFrozenMediaAndCurrentSignature() throws {
        let f = try BackupFixture()
        defer { f.cleanUp() }
        let original = BackupJobDTO(f.job)
        let originalProfile = BackupProfileDTO(f.business)
        let oldReport = try XCTUnwrap(try f.reports.versions(for: f.job).first)
        let oldPDF = try Data(contentsOf: f.media.url(for: oldReport.pdfPath))
        let originalAck = try XCTUnwrap(try AcknowledgmentRepository(context: f.context).record(for: f.job))
        let package = try f.service.makeBackup()
        f.job.customerName = "Changed after backup"
        f.business.businessName = "Changed branding"
        try f.context.save()
        try f.service.restore(f.service.validate(package))
        let fresh = ModelContext(f.container)
        let restored = try XCTUnwrap(try fresh.fetch(FetchDescriptor<JobRecord>()).first { $0.id == f.job.id })
        var actual = BackupJobDTO(restored)
        actual.captureData = original.captureData
        actual.acknowledgmentData = original.acknowledgmentData
        actual.reportsData = original.reportsData
        XCTAssertEqual(actual, original)
        let trash = try XCTUnwrap(try fresh.fetch(FetchDescriptor<JobRecord>()).first { $0.id != f.job.id })
        XCTAssertNotNil(trash.deletedAt)
        XCTAssertNil(trash.captureData)
        XCTAssertNil(trash.acknowledgmentData)
        XCTAssertNil(trash.reportsData)
        let profile = try XCTUnwrap(try fresh.fetch(FetchDescriptor<BusinessProfile>()).first)
        var actualProfile = BackupProfileDTO(profile)
        actualProfile.logoImagePath = originalProfile.logoImagePath
        XCTAssertEqual(actualProfile, originalProfile)
        let document = try CaptureRepository(context: fresh, media: f.media).document(for: restored)
        XCTAssertTrue(document.photos.allSatisfy { $0.imagePath.hasPrefix("Restores/") })
        let originalCapture = try JSONDecoder().decode(CaptureDocument.self, from: XCTUnwrap(original.captureData))
        var visibleCapture = document
        for index in visibleCapture.photos.indices {
            visibleCapture.photos[index].imagePath = originalCapture.photos[index].imagePath
            visibleCapture.photos[index].thumbnailPath = originalCapture.photos[index].thumbnailPath
        }
        XCTAssertEqual(visibleCapture, originalCapture)
        let ack = try XCTUnwrap(try AcknowledgmentRepository(context: fresh).record(for: restored))
        XCTAssertEqual(ack.contentDigest, try AcknowledgmentContentDigest.make(for: restored, document: document))
        var visibleAck = ack
        visibleAck.contentDigest = originalAck.contentDigest
        XCTAssertEqual(visibleAck, originalAck)
        let report = try XCTUnwrap(try ReportRepository(context: fresh, media: f.media).versions(for: restored).first)
        XCTAssertEqual(report.sha256, oldReport.sha256)
        XCTAssertEqual(try Data(contentsOf: f.media.url(for: report.pdfPath)), oldPDF)
        XCTAssertNotEqual(report.snapshot.capture.photos.first?.imagePath, oldReport.snapshot.capture.photos.first?.imagePath)
        var visibleSnapshot = report.snapshot
        visibleSnapshot.logoImagePath = oldReport.snapshot.logoImagePath
        visibleSnapshot.capture = oldReport.snapshot.capture
        visibleSnapshot.acknowledgment.contentDigest = oldReport.snapshot.acknowledgment.contentDigest
        XCTAssertEqual(visibleSnapshot, oldReport.snapshot)
        var visibleReport = report
        visibleReport.pdfPath = oldReport.pdfPath
        visibleReport.snapshot = oldReport.snapshot
        XCTAssertEqual(visibleReport, oldReport)
        // Backing up the rebased history must validate again, including its frozen acknowledgment.
        XCTAssertNoThrow(try BackupService(context: fresh, media: f.media).makeBackup())
        for (old, mapped) in zip(oldReport.snapshot.capture.photos, report.snapshot.capture.photos) {
            XCTAssertEqual(try Data(contentsOf: f.media.url(for: mapped.imagePath)), try Data(contentsOf: f.media.url(for: old.imagePath)))
            XCTAssertEqual(try Data(contentsOf: f.media.url(for: mapped.thumbnailPath)), try Data(contentsOf: f.media.url(for: old.thumbnailPath)))
        }
        XCTAssertEqual(try Data(contentsOf: f.media.url(for: XCTUnwrap(report.snapshot.logoImagePath))), try Data(contentsOf: f.media.url(for: XCTUnwrap(oldReport.snapshot.logoImagePath))))
    }

    // Catches silently making an old signature current after editing signed job details.
    @MainActor
    func testStaleLiveAcknowledgmentRemainsStaleAndUnchanged() throws {
        let f = try BackupFixture()
        defer { f.cleanUp() }
        f.job.plate = "EDITED"
        try f.context.save()
        let old = f.job.acknowledgmentData
        try f.service.restore(f.service.validate(f.service.makeBackup()))
        let fresh = ModelContext(f.container)
        let job = try XCTUnwrap(try fresh.fetch(FetchDescriptor<JobRecord>()).first { $0.id == f.job.id })
        XCTAssertEqual(job.acknowledgmentData, old)
        XCTAssertFalse(try AcknowledgmentRepository(context: fresh).isCurrent(job: job))
    }

    // Catches partial database replacement, overwrite of old media or leaked stage files on save failure.
    @MainActor
    func testFailedRestoreLeavesOldRowsAndFilesUnchanged() throws {
        enum Failure: Error { case save }
        let f = try BackupFixture()
        defer { f.cleanUp() }
        let package = try f.service.makeBackup()
        f.job.customerName = "Keep current rows"
        try f.context.save()
        let rows = try f.context.fetch(FetchDescriptor<JobRecord>()).map(BackupJobDTO.init)
        let profile = BackupProfileDTO(f.business)
        let files = try f.files()
        let failing = BackupService(context: f.context, media: f.media, commit: { _, changes in
            try changes()
            throw Failure.save
        })
        XCTAssertThrowsError(try failing.restore(failing.validate(package)))
        let fresh = ModelContext(f.container)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<JobRecord>()).map(BackupJobDTO.init).sorted { $0.id.uuidString < $1.id.uuidString }, rows.sorted { $0.id.uuidString < $1.id.uuidString })
        XCTAssertEqual(BackupProfileDTO(try XCTUnwrap(try fresh.fetch(FetchDescriptor<BusinessProfile>()).first)), profile)
        XCTAssertEqual(try f.files(), files)
    }

    // Catches accepting a different decodable staged image, including a same-size SHA mismatch.
    @MainActor
    func testChangedValidStagedImageFailsBeforeCommitAndRemovesOnlyStage() throws {
        for preserveByteCount in [true, false] {
            let f = try BackupFixture()
            defer { f.cleanUp() }
            let backup = try f.service.validate(f.service.makeBackup())
            f.job.customerName = "Keep current evidence"
            try f.context.save()
            let originalRows = try f.context.fetch(FetchDescriptor<JobRecord>()).map(BackupJobDTO.init).sorted { $0.id.uuidString < $1.id.uuidString }
            let originalProfile = BackupProfileDTO(f.business)
            let originalFiles = try f.files()
            let differentImage = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).jpegData(withCompressionQuality: 0.9) { renderer in
                UIColor.red.setFill()
                renderer.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
            }
            var changedPath: String?
            var reachedCommit = false
            let service = BackupService(context: f.context, media: f.media, commit: { context, changes in
                reachedCommit = true
                try context.transaction(block: changes)
            }, readStagedAsset: { path in
                let bytes = try f.media.readRegularAsset(at: path)
                if changedPath == nil, bytes.starts(with: [0xFF, 0xD8]) {
                    var changed = differentImage
                    if preserveByteCount {
                        guard changed.count <= bytes.count else { throw CocoaError(.fileReadCorruptFile) }
                        changed.append(Data(repeating: 0, count: bytes.count - changed.count))
                        XCTAssertEqual(changed.count, bytes.count)
                    } else {
                        XCTAssertNotEqual(changed.count, bytes.count)
                    }
                    XCTAssertNotNil(UIImage(data: changed))
                    XCTAssertNotEqual(changed, bytes)
                    try changed.write(to: f.media.url(for: path), options: .atomic)
                    changedPath = path
                }
                return try f.media.readRegularAsset(at: path)
            })
            XCTAssertThrowsError(try service.restore(backup))
            XCTAssertNotNil(changedPath)
            XCTAssertFalse(reachedCommit)
            let fresh = ModelContext(f.container)
            XCTAssertEqual(try fresh.fetch(FetchDescriptor<JobRecord>()).map(BackupJobDTO.init).sorted { $0.id.uuidString < $1.id.uuidString }, originalRows)
            XCTAssertEqual(BackupProfileDTO(try XCTUnwrap(try fresh.fetch(FetchDescriptor<BusinessProfile>()).first)), originalProfile)
            XCTAssertEqual(try f.files(), originalFiles)
            let stagedURL = try f.media.url(for: XCTUnwrap(changedPath))
            XCTAssertFalse(FileManager.default.fileExists(atPath: stagedURL.deletingLastPathComponent().path))
        }
    }

    // Catches lowering reservations or failing to migrate old nil-ledger report histories.
    @MainActor
    func testOlderBackupMergesBothLedgersAndHistoriesWithoutReissuingNumbers() throws {
        let f = try BackupFixture()
        defer { f.cleanUp() }
        f.business.reportNumberLedgerData = nil
        try f.context.save()
        let package = try f.service.makeBackup()
        var report = try XCTUnwrap(try f.reports.versions(for: f.job).first)
        report.reportNumber = "DH-20260903-0072"
        f.job.reportsData = try JSONEncoder().encode([report])
        f.business.reportNumberLedgerData = Data("{\"schemaVersion\":1,\"highWaterByDay\":{\"20260904\":99}}".utf8)
        try f.context.save()
        try f.service.restore(f.service.validate(package))
        let profile = try XCTUnwrap(try ModelContext(f.container).fetch(FetchDescriptor<BusinessProfile>()).first)
        XCTAssertEqual(try ReportNumberLedger.decode(profile.reportNumberLedgerData).highWaterByDay, ["20260903": 72, "20260904": 99])
    }

    // Catches treating malformed/missing metadata or conflicting global report ownership as valid.
    @MainActor
    func testRejectsCorruptManifestAndGraphBeforeMutation() throws {
        let f = try BackupFixture()
        defer { f.cleanUp() }
        let mutations: [(inout BackupManifest) throws -> Void] = [
            { $0.schemaVersion = 2 },
            { $0.jobs.append($0.jobs[0]) },
            { $0.assets.append($0.assets[0]) },
            { $0.assets.removeLast() },
            { $0.assets[0].sha256 = String(repeating: "0", count: 64) },
            { $0.assets[0].byteCount += 1 },
            { $0.assets[0].relativePath = "../escape" },
            { $0.assets[0].relativePath = "/absolute.jpg" },
            { $0.assets[0].relativePath = "C:\\escape.jpg" },
            { $0.jobs[0].captureData = Data("{}".utf8) },
            { $0.jobs[0].statusRawValue = "unsupported" },
            { $0.profile.configurationData = Data("{}".utf8) },
            { $0.profile.reportNumberLedgerData = Data("{}".utf8) },
            { manifest in
                var duplicate = try XCTUnwrap(manifest.jobs.first { $0.reportsData != nil })
                duplicate.id = UUID()
                var reports = try JSONDecoder().decode([ReportVersion].self, from: XCTUnwrap(duplicate.reportsData))
                reports[0].snapshot.jobID = duplicate.id
                duplicate.reportsData = try JSONEncoder().encode(reports)
                manifest.jobs.append(duplicate)
            }
        ]
        let originalFiles = try f.files()
        for mutate in mutations {
            let changed = try mutated(f.service.makeBackup(), mutate)
            XCTAssertThrowsError(try f.service.validate(changed))
            XCTAssertEqual(try f.files(), originalFiles)
            XCTAssertEqual(f.job.customerName, "Ada Customer")
        }
    }

    // Catches symlink resolution, unexpected files and unlisted assets being silently accepted.
    @MainActor
    func testRejectsSymlinkExtraFileMissingFileAndTamperedBytes() throws {
        let f = try BackupFixture()
        defer { f.cleanUp() }
        for variant in 0..<4 {
            let package = try f.service.makeBackup()
            if variant == 0 {
                let link = FileWrapper(symbolicLinkWithDestinationURL: f.root)
                link.preferredFilename = "link"
                try XCTUnwrap(package.fileWrappers?["assets"]).addFileWrapper(link)
            } else if variant == 1 {
                package.addRegularFile(withContents: Data([1]), preferredFilename: "unlisted.bin")
            } else {
                let assets = try XCTUnwrap(package.fileWrappers?["assets"])
                let leaf = try firstRegular(in: assets)
                if variant == 2 { leaf.parent.removeFileWrapper(leaf.file) }
                else {
                    let key = try XCTUnwrap(leaf.file.preferredFilename)
                    leaf.parent.removeFileWrapper(leaf.file)
                    leaf.parent.addRegularFile(withContents: Data([0]), preferredFilename: key)
                }
            }
            XCTAssertThrowsError(try f.service.validate(package))
        }
    }

    // Catches accepting a corrupt image/PDF even if the manifest checksum was updated to match it.
    @MainActor
    func testRejectsChecksummedButUnreadableMedia() throws {
        let f = try BackupFixture()
        defer { f.cleanUp() }
        for suffix in [".jpg", ".pdf"] {
            let package = try f.service.makeBackup()
            let changed = try mutated(package) { manifest in
                let index = try XCTUnwrap(manifest.assets.firstIndex { $0.relativePath.hasSuffix(suffix) })
                let path = manifest.assets[index].relativePath
                let bytes = Data("invalid media".utf8)
                manifest.assets[index].byteCount = bytes.count
                manifest.assets[index].sha256 = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
                var folder = try XCTUnwrap(package.fileWrappers?["assets"])
                let parts = path.split(separator: "/").map(String.init)
                for part in parts.dropLast() { folder = try XCTUnwrap(folder.fileWrappers?[part]) }
                folder.removeFileWrapper(try XCTUnwrap(folder.fileWrappers?[parts.last!]))
                folder.addRegularFile(withContents: bytes, preferredFilename: parts.last!)
            }
            XCTAssertThrowsError(try f.service.validate(changed))
        }
    }

    // Catches exporting thumbnails instead of originals or losing phase/slot/date context.
    @MainActor
    func testPhotoExportIncludesFullBeforeAfterPhotosAndManifest() throws {
        let f = try BackupFixture()
        defer { f.cleanUp() }
        let package = try f.service.exportPhotos(for: f.job)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(PhotoExportManifest.self, from: XCTUnwrap(package.fileWrappers?["manifest.json"]?.regularFileContents))
        XCTAssertEqual(manifest.jobID, f.job.id)
        XCTAssertEqual(manifest.photos.map(\.phase), [.before, .after])
        XCTAssertEqual(manifest.photos.map(\.slotName), ["Front", "Front"])
        XCTAssertTrue(manifest.photos.allSatisfy { $0.capturedAt == f.date })
        let capture = try CaptureRepository(context: f.context, media: f.media).document(for: f.job)
        for (entry, photo) in zip(manifest.photos, capture.photos) {
            XCTAssertEqual(package.fileWrappers?[entry.filename]?.regularFileContents, try Data(contentsOf: f.media.url(for: photo.imagePath)))
        }
    }

    // Catches preserving rows absent from the imported backup or relying on cached in-memory models.
    @MainActor
    func testRestoreIntoDiskStoreReplacesRowsAndFreshContextReadsExactPayloads() throws {
        let source = try BackupFixture()
        defer { source.cleanUp() }
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destination) }
        let container = try ModelContainer(for: BusinessProfile.self, JobRecord.self, configurations: ModelConfiguration(url: destination.appendingPathComponent("store.sqlite")))
        let context = container.mainContext
        context.autosaveEnabled = false
        let overwritten = JobRecord(id: source.job.id, customerName: "Replace me", vehicleLabel: "Wrong", plate: "", color: "", serviceName: "Old", notes: "Old")
        let removed = JobRecord(customerName: "Not in backup", vehicleLabel: "Remove", plate: "", color: "", serviceName: "Old", notes: "")
        context.insert(overwritten)
        context.insert(removed)
        context.insert(BusinessProfile(businessName: "Old profile"))
        try context.save()
        let media = MediaStore(root: destination.appendingPathComponent("Media"))
        let service = BackupService(context: context, media: media)
        try service.restore(service.validate(source.service.makeBackup()))
        let fresh = ModelContext(container)
        let jobs = try fresh.fetch(FetchDescriptor<JobRecord>())
        XCTAssertEqual(jobs.count, 2)
        XCTAssertFalse(jobs.contains { $0.id == removed.id })
        let restored = try XCTUnwrap(jobs.first { $0.id == source.job.id })
        XCTAssertEqual(restored.customerName, "Ada Customer")
        XCTAssertEqual(restored.customerPhone, "12345")
        XCTAssertEqual(restored.customerEmail, "ada@example.test")
        XCTAssertEqual(restored.location, "Garage")
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<BusinessProfile>()).map(\.businessName), ["Detail Team"])
        XCTAssertNoThrow(try BackupService(context: fresh, media: media).makeBackup())
    }

    // Catches omitting unlinked original evidence that only a historical report still references.
    @MainActor
    func testBackupIncludesPhotosAndLogoReferencedOnlyByFrozenReport() throws {
        let f = try BackupFixture()
        defer { f.cleanUp() }
        let originalReport = try XCTUnwrap(try f.reports.versions(for: f.job).first)
        try f.reports.beginRevision(job: f.job)
        f.job.captureData = try JSONEncoder().encode(CaptureDocument())
        f.business.logoImagePath = nil
        try f.context.save()
        let package = try f.service.makeBackup()
        try f.service.restore(f.service.validate(package))
        let fresh = ModelContext(f.container)
        let restored = try XCTUnwrap(try fresh.fetch(FetchDescriptor<JobRecord>()).first { $0.id == f.job.id })
        XCTAssertFalse(try AcknowledgmentRepository(context: fresh).isCurrent(job: restored))
        let report = try XCTUnwrap(try ReportRepository(context: fresh, media: f.media).versions(for: restored).first)
        XCTAssertEqual(report.snapshot.capture.photos.count, 2)
        for (old, new) in zip(originalReport.snapshot.capture.photos, report.snapshot.capture.photos) {
            XCTAssertEqual(try f.media.readRegularAsset(at: old.imagePath), try f.media.readRegularAsset(at: new.imagePath))
        }
        XCTAssertNotNil(report.snapshot.logoImagePath)
        XCTAssertNoThrow(try BackupService(context: fresh, media: f.media).makeBackup())
    }

    // Catches materializing absent legacy payloads and changing the meaning of nil on restore.
    @MainActor
    func testLegacyNilPayloadsRoundTripWithoutMaterializingDefaults() throws {
        let f = try BackupFixture()
        defer { f.cleanUp() }
        f.job.captureData = nil
        f.job.acknowledgmentData = nil
        f.job.reportsData = nil
        f.job.customerPhone = nil
        f.job.customerEmail = nil
        f.job.location = nil
        f.business.configurationData = nil
        f.business.logoImagePath = nil
        f.business.reportNumberLedgerData = nil
        try f.context.save()
        let original = BackupJobDTO(f.job)
        let business = BackupProfileDTO(f.business)
        try f.service.restore(f.service.validate(f.service.makeBackup()))
        let fresh = ModelContext(f.container)
        XCTAssertEqual(BackupJobDTO(try XCTUnwrap(try fresh.fetch(FetchDescriptor<JobRecord>()).first { $0.id == f.job.id })), original)
        XCTAssertEqual(BackupProfileDTO(try XCTUnwrap(try fresh.fetch(FetchDescriptor<BusinessProfile>()).first)), business)
    }

    // Catches checking only live acknowledgment validity and legitimizing tampered frozen evidence.
    @MainActor
    func testRejectsStaleFrozenSignatureAndBrokenFindingReferences() throws {
        let f = try BackupFixture()
        defer { f.cleanUp() }
        for frozen in [true, false] {
            let changed = try mutated(f.service.makeBackup()) { manifest in
                let index = try XCTUnwrap(manifest.jobs.firstIndex { $0.reportsData != nil })
                if frozen {
                    var reports = try JSONDecoder().decode([ReportVersion].self, from: XCTUnwrap(manifest.jobs[index].reportsData))
                    reports[0].snapshot.plate = "Not what was signed"
                    manifest.jobs[index].reportsData = try JSONEncoder().encode(reports)
                } else {
                    var capture = try JSONDecoder().decode(CaptureDocument.self, from: XCTUnwrap(manifest.jobs[index].captureData))
                    capture.findings[0].photoIDs = [UUID()]
                    manifest.jobs[index].captureData = try JSONEncoder().encode(capture)
                }
            }
            XCTAssertThrowsError(try f.service.validate(changed))
        }
    }

    // Catches trusting the imported payload instead of taking each day's larger reservation.
    @MainActor
    func testIncomingLedgerHigherReservationSurvivesAlongsideLocalDays() throws {
        let f = try BackupFixture()
        defer { f.cleanUp() }
        f.business.reportNumberLedgerData = Data("{\"schemaVersion\":1,\"highWaterByDay\":{\"20260902\":150,\"20260904\":500}}".utf8)
        try f.context.save()
        let backup = try f.service.validate(f.service.makeBackup())
        f.business.reportNumberLedgerData = Data("{\"schemaVersion\":1,\"highWaterByDay\":{\"20260903\":72,\"20260904\":99}}".utf8)
        try f.context.save()
        try f.service.restore(backup)
        let profile = try XCTUnwrap(try ModelContext(f.container).fetch(FetchDescriptor<BusinessProfile>()).first)
        XCTAssertEqual(try ReportNumberLedger.decode(profile.reportNumberLedgerData).highWaterByDay, ["20260902": 150, "20260903": 72, "20260904": 500])
    }

    // Catches missing cross-job ownership checks, rather than only invalidating the cloned signature.
    @MainActor
    func testReportIDPathAndNumberConflictsAreRejectedAsOwnershipConflicts() throws {
        let f = try BackupFixture()
        defer { f.cleanUp() }
        for conflict in ["id", "path", "number"] {
            let changed = try mutated(f.service.makeBackup()) { manifest in
                var duplicate = BackupJobDTO(JobRecord(customerName: "Clone", vehicleLabel: "Car", plate: "", color: "", serviceName: "Wash", notes: ""))
                var report = try XCTUnwrap(try f.reports.versions(for: f.job).first)
                report.snapshot.jobID = duplicate.id
                if conflict != "id" { report.id = UUID() }
                if conflict != "path" { report.pdfPath = "new-report.pdf" }
                duplicate.reportsData = try JSONEncoder().encode([report])
                manifest.jobs.append(duplicate)
            }
            XCTAssertThrowsError(try f.service.validate(changed)) { error in
                guard case BackupError.invalidPackage(let detail) = error else { return XCTFail("Wrong failure: \(error)") }
                XCTAssertEqual(detail, "conflicting report identifiers or numbers")
            }
        }
    }

    @MainActor
    private func mutated(_ package: FileWrapper, _ mutation: (inout BackupManifest) throws -> Void) throws -> FileWrapper {
        let wrapper = try XCTUnwrap(package.fileWrappers?["manifest.json"])
        var manifest = try JSONDecoder().decode(BackupManifest.self, from: XCTUnwrap(wrapper.regularFileContents))
        try mutation(&manifest)
        package.removeFileWrapper(wrapper)
        package.addRegularFile(withContents: try JSONEncoder().encode(manifest), preferredFilename: "manifest.json")
        return package
    }

    private func firstRegular(in folder: FileWrapper) throws -> (parent: FileWrapper, file: FileWrapper) {
        for child in (folder.fileWrappers ?? [:]).values {
            if child.isRegularFile { return (folder, child) }
            if child.isDirectory, let found = try? firstRegular(in: child) { return found }
        }
        throw NSError(domain: "Missing fixture asset", code: 1)
    }
}

@MainActor
private final class BackupFixture {
    let container: ModelContainer
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let date = Date(timeIntervalSince1970: 1_788_480_000)
    let job: JobRecord
    let business: BusinessProfile
    var context: ModelContext { container.mainContext }
    var media: MediaStore { MediaStore(root: root) }
    var service: BackupService { BackupService(context: context, media: media) }
    var reports: ReportRepository {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return ReportRepository(context: context, media: media, now: { self.date }, calendar: calendar)
    }

    init() throws {
        let fixtureDate = Date(timeIntervalSince1970: 1_788_480_000)
        container = try ModelContainer(for: BusinessProfile.self, JobRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        job = JobRecord(customerName: "Ada Customer", customerPhone: "12345", customerEmail: "ada@example.test", vehicleLabel: "Blue Car", plate: "ABC", color: "Blue", serviceName: "Full Detail", notes: "Keep all notes", location: "Garage", status: .review, createdAt: fixtureDate, serviceStartedAt: fixtureDate, serviceFinishedAt: fixtureDate)
        business = BusinessProfile(businessName: "Detail Team", phone: "555", email: "team@example.test", disclaimer: "Condition only", configurationData: try JSONEncoder().encode(BusinessConfiguration.standard), createdAt: fixtureDate)
        context.autosaveEnabled = false
        context.insert(job)
        context.insert(business)
        context.insert(JobRecord(customerName: "Trashed", vehicleLabel: "Trash", plate: "", color: "", serviceName: "Wash", notes: "", deletedAt: date))
        let image = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 480)).jpegData(withCompressionQuality: 0.9) { renderer in
            UIColor.blue.setFill()
            renderer.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
        }
        business.logoImagePath = try media.storeBusinessLogo(image)
        var capture = CaptureDocument(skips: CapturePhase.allCases.flatMap { phase in CaptureSlot.standard.map { CaptureSkip(slotID: $0.id, phase: phase, reason: "Unavailable") } })
        for phase in CapturePhase.allCases {
            let stored = try media.storeImage(image, jobID: job.id)
            capture.photos.append(CapturedPhoto(slotID: "front", phase: phase, imagePath: stored.imagePath, thumbnailPath: stored.thumbnailPath, capturedAt: date))
        }
        capture.findings = [VehicleFinding(slotID: "front", kind: "Scratch", severity: "Minor", notes: "Mark", photoIDs: [capture.photos[0].id])]
        job.captureData = try JSONEncoder().encode(capture)
        try context.save()
        try AcknowledgmentRepository(context: context).sign(job: job, name: "Ada Signed", strokes: [SignatureStroke(points: [SignaturePoint(x: 0.1, y: 0.2), SignaturePoint(x: 0.8, y: 0.6)])])
        _ = try reports.seal(job: job, business: business)
    }

    func files() throws -> [String: Data] {
        let files = (FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])?.allObjects as? [URL] ?? []).filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
        return try Dictionary(uniqueKeysWithValues: files.map { ($0.path, try Data(contentsOf: $0)) })
    }

    func cleanUp() { try? FileManager.default.removeItem(at: root) }
}
