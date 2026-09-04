import CryptoKit
import PDFKit
import SwiftData
import UIKit
import XCTest
@testable import DetailHandoff

final class ReportRepositoryTests: XCTestCase {
    // Catches omitted photos/slots, clipped long text, missing branding or evidence labels.
    @MainActor
    func testFortyPhotoPDFPaginatesAllEvidenceAndLongNotes() throws {
        let fixture = try ReportFixture(photoCount: 40, signed: true)
        defer { fixture.cleanUp() }
        fixture.job.notes = (0..<180).map { "Note \($0): Inspect visible surfaces carefully and record the observed condition." }.joined(separator: "\n") + "\nEND-OF-LONG-NOTES"
        let version = try fixture.repository.seal(job: fixture.job, business: fixture.business)
        let data = try Data(contentsOf: fixture.media.url(for: version.pdfPath))
        let pdf = try XCTUnwrap(PDFDocument(data: data))
        let content = try XCTUnwrap(pdf.string)
        XCTAssertGreaterThan(pdf.pageCount, 10)
        for required in ["North Star Detail", "Marcus Lee", "Honda Accord", "7HKL248", "Pearl White", "Full detail", "Service started", "Service finished", "END-OF-LONG-NOTES", "Scratch", "Minor", "Door edge mark", "Acknowledgment", "visible vehicle condition", "Evidence only", version.reportNumber, "Version 1"] {
            XCTAssertTrue(content.contains(required), "Missing PDF text: \(required)")
        }
        for phase in ["Before", "After"] {
            for slot in CaptureSlot.standard {
                XCTAssertTrue(content.contains("\(phase) / \(slot.name)"), "Missing \(phase) / \(slot.name)")
            }
        }
        for photo in fixture.document.photos {
            XCTAssertTrue(content.contains(photo.id.uuidString), "Missing photo reference")
        }
        for index in 0..<pdf.pageCount {
            let page = try XCTUnwrap(pdf.page(at: index))
            XCTAssertEqual(page.bounds(for: .mediaBox).size, CGSize(width: 612, height: 792))
            XCTAssertTrue(page.string?.contains("Page \(index + 1)") == true)
        }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "DetailHandoff-40-photo-signed-report.pdf"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // Catches preview accidentally sealing or hiding unavailable acknowledgments/skips.
    @MainActor
    func testPreviewIsDraftAndDoesNotMutateOrWritePDF() throws {
        let fixture = try ReportFixture()
        defer { fixture.cleanUp() }
        let timestamp = fixture.job.updatedAt
        let files = fixture.files()
        let data = try fixture.repository.preview(job: fixture.job, business: fixture.business)
        let text = try XCTUnwrap(PDFDocument(data: data)?.string)
        XCTAssertTrue(text.contains("DRAFT"))
        XCTAssertTrue(text.contains("CUSTOMER UNAVAILABLE"))
        XCTAssertTrue(text.contains("Keys left with office"))
        XCTAssertTrue(text.contains("Not accessible"))
        XCTAssertEqual(fixture.job.status, .review)
        XCTAssertNil(fixture.job.reportsData)
        XCTAssertEqual(fixture.job.updatedAt, timestamp)
        XCTAssertEqual(fixture.files(), files)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "DetailHandoff-unavailable-draft.pdf"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // Catches mutable snapshots, overwritten PDFs, missing hash and revision persistence.
    @MainActor
    func testSealingAndRevisionPersistFrozenVersionsAndMatchingHash() throws {
        let fixture = try ReportFixture(photoCount: 1)
        defer { fixture.cleanUp() }
        let first = try fixture.repository.seal(job: fixture.job, business: fixture.business)
        let originalBytes = try Data(contentsOf: fixture.media.url(for: first.pdfPath))
        XCTAssertEqual(first.sha256, SHA256.hash(data: originalBytes).map { String(format: "%02x", $0) }.joined())
        XCTAssertEqual(first.reportNumber, "DH-20260904-0001")
        XCTAssertEqual(first.version, 1)
        try fixture.repository.beginRevision(job: fixture.job)
        XCTAssertEqual(fixture.job.status, .review)
        fixture.job.notes = "Revised notes"
        fixture.business.businessName = "New branding"
        let second = try fixture.repository.seal(job: fixture.job, business: fixture.business)
        XCTAssertEqual(second.reportNumber, first.reportNumber)
        XCTAssertEqual(second.version, 2)
        XCTAssertNotEqual(second.pdfPath, first.pdfPath)
        XCTAssertEqual(try Data(contentsOf: fixture.media.url(for: first.pdfPath)), originalBytes)
        let fresh = ModelContext(fixture.container)
        let reloaded = try XCTUnwrap(try fresh.fetch(FetchDescriptor<JobRecord>()).first)
        let versions = try ReportRepository(context: fresh, media: fixture.media).versions(for: reloaded)
        XCTAssertEqual(reloaded.status, .finalized)
        XCTAssertEqual(versions, [first, second])
        XCTAssertEqual(versions[0].snapshot.businessName, "North Star Detail")
        XCTAssertEqual(versions[0].snapshot.notes, "Original notes")
    }

    // Catches number reuse when the previous job is trashed or archived.
    @MainActor
    func testNumberAllocationIncludesTrashAndHistoryAndFailsOnExhaustion() throws {
        let fixture = try ReportFixture()
        defer { fixture.cleanUp() }
        let first = try fixture.repository.seal(job: fixture.job, business: fixture.business)
        fixture.job.deletedAt = fixture.now
        fixture.job.status = .archived
        let next = try fixture.makeAdditionalJob()
        let second = try fixture.repository.seal(job: next, business: fixture.business)
        XCTAssertEqual(second.reportNumber, "DH-20260904-0002")
        var lastNumber = first
        lastNumber.reportNumber = "DH-20260904-9999"
        fixture.job.reportsData = try JSONEncoder().encode([lastNumber])
        try fixture.container.mainContext.save()
        let exhausted = try fixture.makeAdditionalJob()
        XCTAssertThrowsError(try fixture.repository.seal(job: exhausted, business: fixture.business)) {
            XCTAssertEqual($0 as? ReportRepositoryError, .numberExhausted)
        }
        XCTAssertEqual(exhausted.status, .review)
        XCTAssertNil(exhausted.reportsData)
    }

    // Catches failed-save PDF leaks, partial metadata and destruction of prior evidence.
    @MainActor
    func testFailedSealSaveRestoresMetadataAndRemovesOnlyNewPDF() throws {
        enum Failure: Error { case save }
        let fixture = try ReportFixture()
        defer { fixture.cleanUp() }
        let first = try fixture.repository.seal(job: fixture.job, business: fixture.business)
        try fixture.repository.beginRevision(job: fixture.job)
        let priorData = fixture.job.reportsData
        let timestamp = fixture.job.updatedAt
        let files = fixture.files()
        let bytes = try Data(contentsOf: fixture.media.url(for: first.pdfPath))
        let failing = ReportRepository(context: fixture.container.mainContext, media: fixture.media, now: { fixture.now }, calendar: fixture.calendar, saveChanges: { throw Failure.save })
        XCTAssertThrowsError(try failing.seal(job: fixture.job, business: fixture.business))
        XCTAssertEqual(fixture.job.status, .review)
        XCTAssertEqual(fixture.job.updatedAt, timestamp)
        XCTAssertEqual(fixture.job.reportsData, priorData)
        XCTAssertEqual(fixture.files(), files)
        XCTAssertEqual(try Data(contentsOf: fixture.media.url(for: first.pdfPath)), bytes)
        let fresh = ModelContext(fixture.container)
        let saved = try XCTUnwrap(try fresh.fetch(FetchDescriptor<JobRecord>()).first)
        XCTAssertEqual(saved.status, .review)
        XCTAssertEqual(saved.reportsData, priorData)
    }

    // Catches accepting absent, stale, malformed or incomplete acknowledgment/evidence.
    @MainActor
    func testSealRejectsInvalidAcknowledgmentAndIncompleteCaptureWithoutMutation() throws {
        let fixture = try ReportFixture()
        defer { fixture.cleanUp() }
        let valid = fixture.job.acknowledgmentData
        for data in [nil, Data([0xFF])] as [Data?] {
            fixture.job.acknowledgmentData = data
            XCTAssertThrowsError(try fixture.repository.seal(job: fixture.job, business: fixture.business))
            XCTAssertEqual(fixture.job.status, .review)
            XCTAssertNil(fixture.job.reportsData)
        }
        fixture.job.acknowledgmentData = valid
        var malformed = try JSONDecoder().decode(AcknowledgmentRecord.self, from: XCTUnwrap(valid))
        malformed.method = .signature
        malformed.unavailableReason = ""
        malformed.strokes = [SignatureStroke(points: [SignaturePoint(x: 0.3, y: 0.3)])]
        fixture.job.acknowledgmentData = try JSONEncoder().encode(malformed)
        XCTAssertThrowsError(try fixture.repository.seal(job: fixture.job, business: fixture.business))
        fixture.job.acknowledgmentData = valid
        fixture.job.plate = "Changed"
        XCTAssertThrowsError(try fixture.repository.seal(job: fixture.job, business: fixture.business)) {
            XCTAssertEqual($0 as? ReportRepositoryError, .staleAcknowledgment)
        }
        fixture.job.plate = "7HKL248"
        var incomplete = fixture.document
        incomplete.skips.removeAll { $0.phase == .after }
        fixture.job.captureData = try JSONEncoder().encode(incomplete)
        XCTAssertThrowsError(try fixture.repository.seal(job: fixture.job, business: fixture.business))
        XCTAssertNil(fixture.job.reportsData)
        XCTAssertEqual(fixture.job.status, .review)
    }

    // Catches finalization before a PDF write succeeds or overwriting an existing obstruction.
    @MainActor
    func testPDFWriteFailurePreservesJobAndExistingFiles() throws {
        let fixture = try ReportFixture(photoCount: 1)
        defer { fixture.cleanUp() }
        let obstruction = fixture.root.appendingPathComponent("Reports")
        let marker = Data("Existing file must survive".utf8)
        try marker.write(to: obstruction)
        let timestamp = fixture.job.updatedAt
        let files = fixture.files()
        XCTAssertThrowsError(try fixture.repository.seal(job: fixture.job, business: fixture.business))
        XCTAssertEqual(try Data(contentsOf: obstruction), marker)
        XCTAssertEqual(fixture.job.status, .review)
        XCTAssertEqual(fixture.job.updatedAt, timestamp)
        XCTAssertNil(fixture.job.reportsData)
        XCTAssertEqual(fixture.files(), files)
    }

    // Catches UTC-based numbering when the user's local date has already changed.
    @MainActor
    func testNumberUsesLocalDateAndLegacyNilReportsRemainReadable() throws {
        let fixture = try ReportFixture()
        defer { fixture.cleanUp() }
        XCTAssertEqual(try fixture.repository.versions(for: fixture.job), [])
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let localRepository = ReportRepository(context: fixture.container.mainContext, media: fixture.media, now: { fixture.now.addingTimeInterval(-3600) }, calendar: calendar)
        XCTAssertEqual(try localRepository.seal(job: fixture.job, business: fixture.business).reportNumber, "DH-20260904-0001")
    }

    // Catches silently treating corrupt history as no history and reusing its number.
    @MainActor
    func testCorruptHistoryBlocksSealingWithoutReplacingPayload() throws {
        let fixture = try ReportFixture()
        defer { fixture.cleanUp() }
        fixture.job.reportsData = Data([0xFF])
        XCTAssertThrowsError(try fixture.repository.seal(job: fixture.job, business: fixture.business))
        XCTAssertEqual(fixture.job.reportsData, Data([0xFF]))
        XCTAssertEqual(fixture.job.status, .review)
    }

    // Catches silently omitting unreadable original, thumbnail or logo evidence.
    @MainActor
    func testMissingAndCorruptAssetsBlockSealBeforeStateChanges() throws {
        for target in ["original", "thumbnail", "logo"] {
            for corrupt in [false, true] {
                let fixture = try ReportFixture(photoCount: 1)
                defer { fixture.cleanUp() }
                let photo = try XCTUnwrap(fixture.document.photos.first)
                let path: String
                switch target {
                case "original": path = photo.imagePath
                case "thumbnail": path = photo.thumbnailPath
                default:
                    let logo = try fixture.media.storeImage(ReportFixture.imageData(), jobID: fixture.job.id)
                    path = logo.imagePath
                    fixture.business.logoImagePath = path
                }
                let url = try fixture.media.url(for: path)
                if corrupt { try Data([1, 2, 3]).write(to: url) }
                else { try FileManager.default.removeItem(at: url) }
                let files = fixture.files()
                XCTAssertThrowsError(try fixture.repository.seal(job: fixture.job, business: fixture.business), "Accepted \(target), corrupt=\(corrupt)")
                XCTAssertEqual(fixture.job.status, .review)
                XCTAssertNil(fixture.job.reportsData)
                XCTAssertEqual(fixture.files(), files)
            }
        }
    }

    // Catches revision rollback, generic finalize bypass and deletion of frozen media.
    @MainActor
    func testRevisionGuardsAndCaptureRemovalRetainFrozenFiles() throws {
        enum Failure: Error { case save }
        let fixture = try ReportFixture(photoCount: 1)
        defer { fixture.cleanUp() }
        XCTAssertThrowsError(try fixture.repository.beginRevision(job: fixture.job))
        XCTAssertThrowsError(try JobRepository(context: fixture.container.mainContext).advance(fixture.job))
        _ = try fixture.repository.seal(job: fixture.job, business: fixture.business)
        XCTAssertThrowsError(try fixture.repository.seal(job: fixture.job, business: fixture.business))
        let oldData = fixture.job.reportsData
        let timestamp = fixture.job.updatedAt
        let failing = ReportRepository(context: fixture.container.mainContext, media: fixture.media, saveChanges: { throw Failure.save })
        XCTAssertThrowsError(try failing.beginRevision(job: fixture.job))
        XCTAssertEqual(fixture.job.status, .finalized)
        XCTAssertEqual(fixture.job.updatedAt, timestamp)
        try fixture.repository.beginRevision(job: fixture.job)
        let capture = CaptureRepository(context: fixture.container.mainContext, media: fixture.media)
        let photo = try XCTUnwrap(fixture.document.photos.first)
        for finding in fixture.document.findings { try capture.removeFinding(from: fixture.job, findingID: finding.id) }
        try capture.removePhoto(from: fixture.job, photoID: photo.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try fixture.media.url(for: photo.imagePath).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try fixture.media.url(for: photo.thumbnailPath).path))
        XCTAssertEqual(fixture.job.reportsData, oldData)
    }
}

@MainActor
private final class ReportFixture {
    let container: ModelContainer
    let root: URL
    let media: MediaStore
    let job: JobRecord
    let business: BusinessProfile
    var document: CaptureDocument
    let now = Date(timeIntervalSince1970: 1_788_480_000) // 2026-09-04 00:00 UTC
    let calendar: Calendar
    var repository: ReportRepository {
        ReportRepository(context: container.mainContext, media: media, now: { self.now }, calendar: calendar)
    }

    init(photoCount: Int = 0, signed: Bool = false) throws {
        container = try makeContainer()
        container.mainContext.autosaveEnabled = false
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        media = MediaStore(root: root)
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = localCalendar
        business = BusinessProfile(businessName: "North Star Detail", phone: "555-0100", email: "office@example.test", disclaimer: "Evidence only")
        job = JobRecord(customerName: "Marcus Lee", vehicleLabel: "2021 Honda Accord", plate: "7HKL248", color: "Pearl White", serviceName: "Full detail", notes: "Original notes", status: .review, serviceStartedAt: now.addingTimeInterval(-3600), serviceFinishedAt: now)
        document = CaptureDocument(skips: CapturePhase.allCases.flatMap { phase in
            CaptureSlot.standard.map { CaptureSkip(slotID: $0.id, phase: phase, reason: "Not accessible") }
        })
        for index in 0..<photoCount {
            let stored = try media.storeImage(Self.imageData(index: index), jobID: job.id)
            document.photos.append(CapturedPhoto(slotID: CaptureSlot.standard[index % 12].id, phase: index < 20 ? .before : .after, imagePath: stored.imagePath, thumbnailPath: stored.thumbnailPath, capturedAt: now))
        }
        if let photo = document.photos.first {
            document.findings = [VehicleFinding(slotID: photo.slotID, kind: "Scratch", severity: "Minor", notes: "Door edge mark", photoIDs: [photo.id])]
        }
        job.captureData = try JSONEncoder().encode(document)
        container.mainContext.insert(job)
        container.mainContext.insert(business)
        try container.mainContext.save()
        let acknowledgment = AcknowledgmentRepository(context: container.mainContext)
        if signed {
            try acknowledgment.sign(job: job, name: "Marcus Lee", strokes: [SignatureStroke(points: [SignaturePoint(x: 0.1, y: 0.5), SignaturePoint(x: 0.3, y: 0.2), SignaturePoint(x: 0.6, y: 0.8), SignaturePoint(x: 0.9, y: 0.3)])])
        } else {
            try acknowledgment.markUnavailable(job: job, reason: "Keys left with office")
        }
    }

    func makeAdditionalJob() throws -> JobRecord {
        let additional = JobRecord(customerName: "Marcus Lee", vehicleLabel: "Honda Accord", plate: "7HKL248", color: "White", serviceName: "Wash", notes: "", status: .review)
        additional.captureData = try JSONEncoder().encode(CaptureDocument(skips: CapturePhase.allCases.flatMap { phase in CaptureSlot.standard.map { CaptureSkip(slotID: $0.id, phase: phase, reason: "Not accessible") } }))
        container.mainContext.insert(additional)
        try AcknowledgmentRepository(context: container.mainContext).markUnavailable(job: additional, reason: "Customer away")
        return additional
    }

    static func imageData(index: Int = 0) -> Data {
        let size = CGSize(width: index % 2 == 0 ? 480 : 240, height: index % 2 == 0 ? 240 : 480)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.jpegData(withCompressionQuality: 0.85) { context in
            UIColor(hue: CGFloat(index % 12) / 12, saturation: 0.45, brightness: 0.85, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            ("Evidence photo \(index + 1)" as NSString).draw(at: CGPoint(x: 20, y: 60), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 20), .foregroundColor: UIColor.black])
        }
    }

    func files() -> Set<String> {
        Set((FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])?.allObjects as? [URL] ?? []).filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }.map(\.path))
    }

    func cleanUp() { try? FileManager.default.removeItem(at: root) }
}
