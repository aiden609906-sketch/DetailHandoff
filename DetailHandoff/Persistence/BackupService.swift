import Foundation
import SwiftData
import UIKit

struct ValidatedBackup {
    fileprivate let manifest: BackupManifest
    fileprivate let files: [String: Data]
    var jobCount: Int { manifest.jobs.count }
    var createdAt: Date { manifest.createdAt }
}

extension Notification.Name {
    static let evidenceStoreRestored = Notification.Name("DetailHandoff.evidenceStoreRestored")
}

@MainActor
final class BackupService {
    private let context: ModelContext
    private let media: MediaStore
    private let commit: (ModelContext, () throws -> Void) throws -> Void
    private let readStagedAsset: (String) throws -> Data

    init(context: ModelContext, media: MediaStore, commit: ((ModelContext, () throws -> Void) throws -> Void)? = nil, readStagedAsset: ((String) throws -> Data)? = nil) {
        self.context = context
        self.media = media
        self.commit = commit ?? { context, changes in try context.transaction(block: changes) }
        self.readStagedAsset = readStagedAsset ?? { try media.readRegularAsset(at: $0) }
    }

    func makeBackup() throws -> FileWrapper {
        guard !context.hasChanges else { throw BackupError.unsavedChanges }
        let profiles = try context.fetch(FetchDescriptor<BusinessProfile>())
        guard profiles.count == 1, let profile = profiles.first else { throw BackupError.invalidPackage("one business profile is required") }
        let jobs = try context.fetch(FetchDescriptor<JobRecord>()).sorted { $0.id.uuidString < $1.id.uuidString }
        var manifest = BackupManifest(createdAt: Date(), profile: BackupProfileDTO(profile), jobs: jobs.map(BackupJobDTO.init), assets: [])
        let graph = try BackupGraph(manifest: manifest, context: context, media: media)
        var referencedPaths = Set<String>()
        for job in jobs { referencedPaths.formUnion(try EvidenceAssetReferences.paths(for: job, context: context, media: media)) }
        if let logo = profile.logoImagePath { referencedPaths.insert(logo) }
        var files: [String: Data] = [:]
        for path in referencedPaths.sorted() {
            let bytes = try media.readRegularAsset(at: path)
            files[path] = bytes
            manifest.assets.append(BackupAsset(relativePath: path, byteCount: bytes.count, sha256: BackupPackage.digest(bytes)))
        }
        try graph.validateFiles(files)
        return try BackupPackage.make(manifest: manifest, files: files)
    }

    func validate(_ package: FileWrapper) throws -> ValidatedBackup {
        let (manifest, files) = try BackupPackage.unpack(package)
        let graph = try BackupGraph(manifest: manifest, context: context, media: media)
        try graph.validateFiles(files)
        return ValidatedBackup(manifest: manifest, files: files)
    }

    func restore(_ validated: ValidatedBackup) throws {
        guard !context.hasChanges else { throw BackupError.unsavedChanges }
        // No live model is touched during validation or path rebasing.
        let graph = try BackupGraph(manifest: validated.manifest, context: context, media: media)
        try graph.validateFiles(validated.files)
        let replacement = ModelContext(context.container)
        replacement.autosaveEnabled = false
        let currentProfiles = try replacement.fetch(FetchDescriptor<BusinessProfile>())
        let currentJobs = try replacement.fetch(FetchDescriptor<JobRecord>())
        let ledger = try mergedLedger(incoming: validated.manifest, currentProfiles: currentProfiles, currentJobs: currentJobs, context: replacement)
        let stage = try BackupMediaStage(media: media)
        do {
            let paths = try stage.write(validated.files)
            var rebased = try BackupRebase.apply(to: validated.manifest, paths: paths, graph: graph)
            // Keep unchanged payload bytes (and legacy nil) when no larger reservation was merged.
            if ledger != (try ReportNumberLedger.decode(rebased.profile.reportNumberLedgerData)) {
                rebased.profile.reportNumberLedgerData = try JSONEncoder().encode(ledger)
            }
            let rebasedGraph = try BackupGraph(manifest: rebased, context: replacement, media: media)
            var stagedFiles: [String: Data] = [:]
            for path in paths.values { stagedFiles[path] = try readStagedAsset(path) }
            try BackupPackage.validateAssets(rebased.assets, files: stagedFiles)
            try rebasedGraph.validateFiles(stagedFiles)
            try commit(replacement) {
                let importedIDs = Set(rebased.jobs.map(\.id))
                let existingByID = Dictionary(uniqueKeysWithValues: currentJobs.map { ($0.id, $0) })
                for current in currentJobs where !importedIDs.contains(current.id) { replacement.delete(current) }
                for dto in rebased.jobs {
                    if let current = existingByID[dto.id] { dto.apply(to: current) }
                    else { replacement.insert(dto.makeModel()) }
                }
                for current in currentProfiles where current.id != rebased.profile.id { replacement.delete(current) }
                if let current = currentProfiles.first(where: { $0.id == rebased.profile.id }) { rebased.profile.apply(to: current) }
                else { replacement.insert(rebased.profile.makeModel()) }
            }
        } catch let operationError {
            replacement.rollback()
            do { try stage.discard() }
            catch let cleanupError { throw BackupError.cleanupFailed(operationError, cleanupError) }
            throw operationError
        }
        // Old assets remain intact; reference-aware storage cleanup can reclaim them later.
        // Views must stop using objects cached in the old context, including navigation destinations.
        EvidenceImport.invalidatePendingLoads()
        NotificationCenter.default.post(name: .evidenceStoreRestored, object: context.container)
    }

    func exportPhotos(for job: JobRecord) throws -> FileWrapper {
        let capture = try CaptureRepository(context: context, media: media).document(for: job)
        var entries: [PhotoExportEntry] = []
        var files: [String: FileWrapper] = [:]
        for (index, photo) in capture.photos.enumerated() {
            let bytes = try media.readRegularAsset(at: photo.imagePath)
            guard UIImage(data: bytes)?.cgImage != nil,
                  let slot = capture.slots.first(where: { $0.id == photo.slotID }) else { throw BackupError.invalidPackage("unreadable photo") }
            let filename = "\(photo.phase.rawValue)-\(index + 1)-\(photo.id.uuidString).jpg"
            files[filename] = FileWrapper(regularFileWithContents: bytes)
            entries.append(PhotoExportEntry(photoID: photo.id, phase: photo.phase, slotID: slot.id, slotName: slot.name, capturedAt: photo.capturedAt, filename: filename, sha256: BackupPackage.digest(bytes)))
        }
        let manifest = PhotoExportManifest(jobID: job.id, vehicleLabel: job.vehicleLabel, photos: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        files["manifest.json"] = FileWrapper(regularFileWithContents: try encoder.encode(manifest))
        return FileWrapper(directoryWithFileWrappers: files)
    }

    private func mergedLedger(incoming: BackupManifest, currentProfiles: [BusinessProfile], currentJobs: [JobRecord], context: ModelContext) throws -> ReportNumberLedger {
        guard currentProfiles.count <= 1 else { throw BackupError.invalidPackage("duplicate current business profiles") }
        var result = try ReportNumberLedger.decode(incoming.profile.reportNumberLedgerData)
        for profile in currentProfiles {
            for (day, maximum) in try ReportNumberLedger.decode(profile.reportNumberLedgerData).highWaterByDay {
                try result.observe(reportNumber: "DH-\(day)-" + String(format: "%04d", maximum))
            }
        }
        let reports = ReportRepository(context: context, media: media)
        for job in currentJobs + incoming.jobs.map({ $0.makeModel() }) {
            for report in try reports.versions(for: job) { try result.observe(reportNumber: report.reportNumber) }
        }
        return result
    }
}
