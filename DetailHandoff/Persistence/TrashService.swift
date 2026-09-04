import Foundation
import PDFKit
import SwiftData
import UIKit

enum TrashServiceError: LocalizedError, Equatable {
    case expired
    case notDeleted
    case invalidContext
    case unsavedChanges
    case missingBusinessProfile
    case unreadableAsset(String)
    case cleanupIncomplete([String])

    var errorDescription: String? {
        switch self {
        case .expired: "This job’s 30-day recovery period has expired. It can no longer be restored."
        case .notDeleted: "Move this job to Recently deleted before deleting it permanently."
        case .invalidContext: "This job is no longer available. Reopen the jobs list."
        case .unsavedChanges: "Finish saving your current changes, then try again. No files were removed."
        case .missingBusinessProfile: "The business profile is unavailable. Report numbers must be preserved before these jobs can be deleted."
        case .unreadableAsset(let path): "An evidence file cannot be read safely: \(path). Nothing was deleted. Export a backup or resolve the damaged file before retrying."
        case .cleanupIncomplete(let paths): "\(paths.count) file(s) could not be removed. Any completed job deletion remains saved. Remaining files are retained safely. Retry with Clean unreferenced files in Settings → Storage."
        }
    }
}

struct JobStorageUsage: Identifiable {
    let id: UUID
    let title: String
    let customer: String
    let isDeleted: Bool
    let bytes: Int64
}

struct StorageSummary {
    let totalBytes: Int64
    let reclaimableBytes: Int64
    let jobs: [JobStorageUsage]
}

/// No suspension points: imports, report creation, backup replacement and cleanup all serialize
/// on MainActor. A failed metadata save never starts physical cleanup.
@MainActor
final class TrashService {
    static let retentionInterval: TimeInterval = 30 * 24 * 60 * 60
    private let context: ModelContext
    private let media: MediaStore
    private let now: () -> Date
    private let saveChanges: () throws -> Void
    private let removeAsset: (String) throws -> Void

    init(context: ModelContext, media: MediaStore, now: @escaping () -> Date = { Date() }, saveChanges: (() throws -> Void)? = nil, removeAsset: ((String) throws -> Void)? = nil) {
        self.context = context
        self.media = media
        self.now = now
        self.saveChanges = saveChanges ?? { try context.save() }
        self.removeAsset = removeAsset ?? { try media.removeRegularAsset(at: $0) }
    }

    static func expiresAt(_ deletedAt: Date) -> Date { deletedAt.addingTimeInterval(retentionInterval) }

    func softDelete(_ job: JobRecord) throws {
        try requireSavedJob(job)
        guard job.deletedAt == nil else { return }
        let timestamp = now()
        try commit {
            job.deletedAt = timestamp
            job.updatedAt = timestamp
        }
        EvidenceImport.invalidatePendingLoads()
    }

    func restore(_ job: JobRecord) throws {
        try requireSavedJob(job)
        guard let deletedAt = job.deletedAt else { throw TrashServiceError.notDeleted }
        guard now() < Self.expiresAt(deletedAt) else { throw TrashServiceError.expired }
        try commit {
            job.deletedAt = nil
            job.updatedAt = now()
        }
    }

    func permanentlyDelete(_ job: JobRecord) throws {
        try requireSavedJob(job)
        guard job.deletedAt != nil else { throw TrashServiceError.notDeleted }
        try purge([job])
    }

    func purgeExpired() throws {
        let timestamp = now()
        let jobs = try context.fetch(FetchDescriptor<JobRecord>()).filter {
            $0.deletedAt.map { timestamp >= Self.expiresAt($0) } ?? false
        }
        guard !jobs.isEmpty else { return }
        try purge(jobs)
    }

    func storageSummary() throws -> StorageSummary {
        let inventory = try media.assetInventory()
        let jobs = try context.fetch(FetchDescriptor<JobRecord>(sortBy: [SortDescriptor(\JobRecord.createdAt, order: .reverse)]))
        let references = try retainedReferences(jobs: jobs)
        let allReferences = references.values.reduce(into: Set<String>()) { $0.formUnion($1) }
            .union(try brandingReferences())
        let usage = jobs.map { job in
            let paths = references[job.id] ?? []
            return JobStorageUsage(id: job.id, title: job.vehicleLabel, customer: job.customerName,
                                   isDeleted: job.deletedAt != nil,
                                   bytes: inventory.filter { paths.contains(key($0.path)) || belongsToJob($0.path, id: job.id) }.reduce(0) { $0 + $1.bytes })
        }
        return StorageSummary(totalBytes: inventory.reduce(0) { $0 + $1.bytes },
                              reclaimableBytes: inventory.filter { !allReferences.contains(key($0.path)) }.reduce(0) { $0 + $1.bytes },
                              jobs: usage)
    }

    /// The UI must explicitly confirm this irreversible operation. Always derive a new graph
    /// on retry, so files referenced by a subsequent restore/import cannot be removed.
    func cleanOrphans() throws {
        guard !context.hasChanges else { throw TrashServiceError.unsavedChanges }
        let inventory = try media.assetInventory()
        let jobs = try context.fetch(FetchDescriptor<JobRecord>())
        let references = try retainedReferences(jobs: jobs).values.reduce(into: Set<String>()) { $0.formUnion($1) }
            .union(try brandingReferences())
        let candidates = inventory.filter { !references.contains(key($0.path)) }.map(\.path)
        // Validate every candidate before deleting the first, including malformed imported locators.
        for path in candidates { _ = try media.readRegularAsset(at: path) }
        try cleanup(candidates)
    }

    private func purge(_ targets: [JobRecord]) throws {
        guard !context.hasChanges else { throw TrashServiceError.unsavedChanges }
        let allJobs = try context.fetch(FetchDescriptor<JobRecord>())
        let inventory = try media.assetInventory()
        let references = try retainedReferences(jobs: allJobs)
        let targetIDs = Set(targets.map(\.id))
        let retained = references.filter { !targetIDs.contains($0.key) }.values.reduce(into: Set<String>()) { $0.formUnion($1) }
            .union(try brandingReferences())
        let owned = references.filter { targetIDs.contains($0.key) }.values.reduce(into: Set<String>()) { $0.formUnion($1) }
        let candidates = inventory.filter { asset in
            !retained.contains(key(asset.path)) && (owned.contains(key(asset.path)) || targetIDs.contains { belongsToJob(asset.path, id: $0) })
        }.map(\.path)
        // Retention is not permission to silently destroy damaged/unknown evidence.
        for path in candidates { try validateReadableEvidence(path) }

        let profiles = try context.fetch(FetchDescriptor<BusinessProfile>())
        let histories = try allJobs.flatMap { try ReportRepository(context: context, media: media).versions(for: $0) }
        guard profiles.count <= 1, histories.isEmpty || profiles.count == 1 else { throw TrashServiceError.missingBusinessProfile }
        let profile = profiles.first
        let originalLedger = try ReportNumberLedger.decode(profile?.reportNumberLedgerData)
        var ledger = originalLedger
        for report in histories { try ledger.observe(reportNumber: report.reportNumber) }
        let encodedLedger: Data?
        if ledger == originalLedger { encodedLedger = profile?.reportNumberLedgerData }
        else { encodedLedger = try JSONEncoder().encode(ledger) }
        try commit {
            profile?.reportNumberLedgerData = encodedLedger
            for job in targets { context.delete(job) }
        }
        EvidenceImport.invalidatePendingLoads()
        try cleanup(candidates)
    }

    private func retainedReferences(jobs: [JobRecord]) throws -> [UUID: Set<String>] {
        try Dictionary(uniqueKeysWithValues: jobs.map { job in
            let paths = try EvidenceAssetReferences.paths(for: job, context: context, media: media)
            for path in paths { _ = try media.readRegularAsset(at: path) }
            return (job.id, Set(paths.map(key)))
        })
    }

    private func brandingReferences() throws -> Set<String> {
        let paths = try context.fetch(FetchDescriptor<BusinessProfile>()).compactMap(\.logoImagePath)
        for path in paths { _ = try media.readRegularAsset(at: path) }
        return Set(paths.map(key))
    }

    // Conservative alias protection on case-insensitive/Unicode-normalizing file systems.
    private func key(_ path: String) -> String { path.precomposedStringWithCanonicalMapping.lowercased() }

    private func belongsToJob(_ path: String, id: UUID) -> Bool {
        let path = key(path)
        let id = id.uuidString.lowercased()
        return path.hasPrefix(id + "/") || path.hasPrefix("reports/" + id + "/")
    }

    private func validateReadableEvidence(_ path: String) throws {
        let bytes = try media.readRegularAsset(at: path)
        if UIImage(data: bytes) != nil { return }
        if let pdf = PDFDocument(data: bytes), !pdf.isLocked, pdf.pageCount > 0 { return }
        throw TrashServiceError.unreadableAsset(path)
    }

    private func cleanup(_ paths: [String]) throws {
        var failed: [String] = []
        for path in paths {
            do { try removeAsset(path) }
            catch { failed.append(path) }
        }
        if !failed.isEmpty { throw TrashServiceError.cleanupIncomplete(failed) }
    }

    private func requireSavedJob(_ job: JobRecord) throws {
        guard job.modelContext === context, !job.isDeleted else { throw TrashServiceError.invalidContext }
        guard !context.hasChanges else { throw TrashServiceError.unsavedChanges }
    }

    private func commit(_ mutation: () -> Void) throws {
        // No unrelated pending edits enter this save; rollback restores job + ledger together.
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosave }
        mutation()
        do { try saveChanges() }
        catch { context.rollback(); throw error }
    }
}
