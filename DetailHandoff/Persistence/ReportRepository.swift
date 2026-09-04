import CryptoKit
import Darwin
import Foundation
import SwiftData

enum ReportRepositoryError: Error, Equatable {
    case requiresReview
    case requiresFinalized
    case deletedJob
    case corruptHistory
    case incompleteCapture(CapturePhase)
    case missingAcknowledgment
    case staleAcknowledgment
    case numberExhausted
    case versionExhausted
}

struct ReportRepositoryRollbackError: Error {
    let operationError: any Error
    let cleanupError: any Error
}

/// Synchronous MainActor operations serialize numbering and file/database commits in this app.
@MainActor
final class ReportRepository {
    private let context: ModelContext
    private let media: MediaStore
    private let saveChanges: () throws -> Void
    private let now: () -> Date
    private let calendar: Calendar

    init(context: ModelContext, media: MediaStore, now: @escaping () -> Date = { Date() }, calendar: Calendar = .current, saveChanges: (() throws -> Void)? = nil) {
        self.context = context
        self.media = media
        self.now = now
        self.calendar = calendar
        self.saveChanges = saveChanges ?? { try context.save() }
    }

    func versions(for job: JobRecord) throws -> [ReportVersion] {
        guard let data = job.reportsData else { return [] }
        let versions: [ReportVersion]
        do { versions = try JSONDecoder().decode([ReportVersion].self, from: data) }
        catch { throw ReportRepositoryError.corruptHistory }
        var identifiers = Set<UUID>()
        var paths = Set<String>()
        var previousVersion = 0
        for report in versions {
            guard report.snapshot.jobID == job.id,
                  identifiers.insert(report.id).inserted,
                  paths.insert(report.pdfPath).inserted,
                  report.version > previousVersion,
                  report.reportNumber == versions.first?.reportNumber,
                  validNumber(report.reportNumber),
                  report.sha256.count == 64,
                  report.sha256.allSatisfy({ $0.isHexDigit }) else {
                throw ReportRepositoryError.corruptHistory
            }
            _ = try media.url(for: report.pdfPath)
            previousVersion = report.version
        }
        return versions
    }

    func preview(job: JobRecord, business: BusinessProfile) throws -> Data {
        let snapshot = try validatedSnapshot(job: job, business: business)
        let history = try versions(for: job)
        let version = try nextVersion(history)
        return try ReportRenderer.render(snapshot: snapshot, number: history.first?.reportNumber ?? "DRAFT", version: version, sealedAt: now(), media: media, isDraft: true)
    }

    func seal(job: JobRecord, business: BusinessProfile) throws -> ReportVersion {
        let snapshot = try validatedSnapshot(job: job, business: business)
        var history = try versions(for: job)
        let sealedAt = now()
        let number = try history.first?.reportNumber ?? allocateNumber(at: sealedAt)
        let version = try nextVersion(history)
        let pdf = try ReportRenderer.render(snapshot: snapshot, number: number, version: version, sealedAt: sealedAt, media: media)
        let id = UUID()
        let path = "Reports/\(job.id.uuidString)/\(id.uuidString)/report.pdf"
        let report = ReportVersion(id: id, reportNumber: number, version: version, sealedAt: sealedAt, pdfPath: path, sha256: SHA256.hash(data: pdf).map { String(format: "%02x", $0) }.joined(), snapshot: snapshot)
        history.append(report)
        let encoded = try JSONEncoder().encode(history)
        let url = try media.url(for: path)
        let previousData = job.reportsData
        let previousStatus = job.status
        let previousUpdatedAt = job.updatedAt
        let fileManager = FileManager.default
        let versionDirectory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: versionDirectory.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Claim a fresh directory exclusively before writing. If this fails (including a UUID
        // collision), no existing path is owned or removed by this operation.
        guard mkdir(versionDirectory.path, mode_t(S_IRWXU)) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        do {
            // Atomic publication inside our exclusively owned directory also makes partial-write
            // cleanup safe without ever deleting or replacing an older report.
            try pdf.write(to: url, options: .atomic)
            job.reportsData = encoded
            job.status = .finalized
            job.updatedAt = sealedAt
            try saveChanges()
        } catch let operationError {
            job.reportsData = previousData
            job.status = previousStatus
            job.updatedAt = previousUpdatedAt
            do { try fileManager.removeItem(at: versionDirectory) }
            catch let cleanupError {
                throw ReportRepositoryRollbackError(operationError: operationError, cleanupError: cleanupError)
            }
            throw operationError
        }
        return report
    }

    func beginRevision(job: JobRecord) throws {
        guard job.deletedAt == nil else { throw ReportRepositoryError.deletedJob }
        guard job.status == .finalized else { throw ReportRepositoryError.requiresFinalized }
        guard !(try versions(for: job)).isEmpty else { throw ReportRepositoryError.corruptHistory }
        let previousUpdatedAt = job.updatedAt
        job.status = .review
        job.updatedAt = now()
        do { try saveChanges() }
        catch {
            job.status = .finalized
            job.updatedAt = previousUpdatedAt
            throw error
        }
    }

    private func validatedSnapshot(job: JobRecord, business: BusinessProfile) throws -> ReportSnapshot {
        guard job.deletedAt == nil else { throw ReportRepositoryError.deletedJob }
        guard job.status == .review else { throw ReportRepositoryError.requiresReview }
        let document = try CaptureRepository(context: context, media: media).document(for: job)
        for phase in CapturePhase.allCases {
            guard !document.slots.isEmpty, CaptureValidation.missingRequiredSlots(in: document, phase: phase).isEmpty else {
                throw ReportRepositoryError.incompleteCapture(phase)
            }
        }
        let acknowledgmentRepository = AcknowledgmentRepository(context: context)
        guard let acknowledgment = try acknowledgmentRepository.record(for: job) else { throw ReportRepositoryError.missingAcknowledgment }
        guard acknowledgment.contentDigest == (try AcknowledgmentContentDigest.make(for: job, document: document)) else {
            throw ReportRepositoryError.staleAcknowledgment
        }
        return ReportSnapshot(job: job, business: business, capture: document, acknowledgment: acknowledgment)
    }

    private func nextVersion(_ history: [ReportVersion]) throws -> Int {
        let latest = history.last?.version ?? 0
        guard latest < Int.max else { throw ReportRepositoryError.versionExhausted }
        return latest + 1
    }

    private func allocateNumber(at date: Date) throws -> String {
        // Gregorian digits with the user's local calendar time zone, independent of display locale.
        var numberingCalendar = Calendar(identifier: .gregorian)
        numberingCalendar.timeZone = calendar.timeZone
        let components = numberingCalendar.dateComponents([.year, .month, .day], from: date)
        let prefix = String(format: "DH-%04d%02d%02d-", components.year ?? 0, components.month ?? 0, components.day ?? 0)
        var highest = 0
        // Do not filter deleted/archived jobs: their numbers remain permanently reserved.
        for job in try context.fetch(FetchDescriptor<JobRecord>()) {
            for report in try versions(for: job) where report.reportNumber.hasPrefix(prefix) {
                highest = max(highest, Int(report.reportNumber.suffix(4)) ?? 0)
            }
        }
        guard highest < 9999 else { throw ReportRepositoryError.numberExhausted }
        return prefix + String(format: "%04d", highest + 1)
    }

    private func validNumber(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "DH", parts[1].count == 8, parts[2].count == 4,
              parts[1].allSatisfy({ $0.isASCII && $0.isNumber }),
              parts[2].allSatisfy({ $0.isASCII && $0.isNumber }),
              let sequence = Int(parts[2]), sequence > 0 else { return false }
        return true
    }
}
