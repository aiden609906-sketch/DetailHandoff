import Foundation
import PDFKit
import SwiftData
import UIKit

/// Shared live/frozen reference enumeration for backup and reference-aware storage cleanup.
@MainActor
enum EvidenceAssetReferences {
    static func paths(for job: JobRecord, context: ModelContext, media: MediaStore) throws -> Set<String> {
        let capture = try CaptureRepository(context: context, media: media).document(for: job)
        var paths = Set(capture.photos.flatMap { [$0.imagePath, $0.thumbnailPath] })
        for report in try ReportRepository(context: context, media: media).versions(for: job) {
            paths.formUnion(report.snapshot.referencedAssetPaths)
            paths.insert(report.pdfPath)
        }
        return paths
    }
}

@MainActor
struct BackupGraph {
    enum AssetKind: Equatable { case image, pdf(String) }
    private(set) var assets: [String: AssetKind] = [:]
    private(set) var currentAcknowledgments: Set<UUID> = []

    init(manifest: BackupManifest, context: ModelContext, media: MediaStore) throws {
        guard manifest.schemaVersion == 1 else { throw BackupError.invalidPackage("unsupported schema version") }
        if let configuration = manifest.profile.configurationData {
            let config = try JSONDecoder().decode(BusinessConfiguration.self, from: configuration).validated()
            guard Set(config.services.map(\.id)).count == config.services.count,
                  Set(config.templates.map(\.id)).count == config.templates.count else {
                throw BackupError.invalidPackage("duplicate configuration identifiers")
            }
        }
        _ = try ReportNumberLedger.decode(manifest.profile.reportNumberLedgerData)
        if let logo = manifest.profile.logoImagePath { try add(logo, kind: .image) }
        let captures = CaptureRepository(context: context, media: media)
        let acknowledgments = AcknowledgmentRepository(context: context)
        let reports = ReportRepository(context: context, media: media)
        var jobIDs = Set<UUID>()
        var livePhotoIDs = Set<UUID>()
        var reportIDs = Set<UUID>()
        var reportPaths = Set<String>()
        var numberOwners: [String: UUID] = [:]
        for dto in manifest.jobs {
            guard jobIDs.insert(dto.id).inserted, JobStatus(rawValue: dto.statusRawValue) != nil else {
                throw BackupError.invalidPackage("duplicate job ID or unsupported status")
            }
            let job = dto.makeModel()
            let capture = try captures.document(for: job)
            try addCapture(capture)
            for photo in capture.photos {
                guard livePhotoIDs.insert(photo.id).inserted else { throw BackupError.invalidPackage("duplicate photo identifier") }
            }
            if let acknowledgment = try acknowledgments.record(for: job) {
                try validateDigest(acknowledgment.contentDigest)
                if acknowledgment.contentDigest == (try AcknowledgmentContentDigest.make(for: job, document: capture)) {
                    currentAcknowledgments.insert(job.id)
                }
            }
            var numberLedger = ReportNumberLedger()
            for report in try reports.versions(for: job) {
                try numberLedger.observe(reportNumber: report.reportNumber)
                guard reportIDs.insert(report.id).inserted, reportPaths.insert(report.pdfPath).inserted,
                      numberOwners[report.reportNumber] == nil || numberOwners[report.reportNumber] == job.id else {
                    throw BackupError.invalidPackage("conflicting report identifiers or numbers")
                }
                numberOwners[report.reportNumber] = job.id
                let snapshotJob = try Self.snapshotJob(report.snapshot)
                let frozenCapture = try captures.document(for: snapshotJob)
                try addCapture(frozenCapture)
                for phase in CapturePhase.allCases {
                    guard !frozenCapture.slots.isEmpty,
                          CaptureValidation.missingRequiredSlots(in: frozenCapture, phase: phase).isEmpty else {
                        throw BackupError.invalidPackage("incomplete frozen report capture")
                    }
                }
                guard let acknowledgment = try acknowledgments.record(for: snapshotJob),
                      acknowledgment.contentDigest == (try AcknowledgmentContentDigest.makeForFrozenRecord(acknowledgment, job: snapshotJob, document: frozenCapture)) else {
                    throw BackupError.invalidPackage("invalid frozen report acknowledgment")
                }
                if let logo = report.snapshot.logoImagePath { try add(logo, kind: .image) }
                try add(report.pdfPath, kind: .pdf(report.sha256))
            }
        }
    }

    func validateFiles(_ files: [String: Data]) throws {
        guard Set(files.keys) == Set(assets.keys) else { throw BackupError.invalidPackage("missing or unreferenced assets") }
        for (path, kind) in assets {
            guard let bytes = files[path] else { throw BackupError.invalidPackage("missing asset") }
            switch kind {
            case .image:
                guard let image = UIImage(data: bytes), let cgImage = image.cgImage,
                      cgImage.width > 0, cgImage.height > 0 else { throw BackupError.invalidPackage("unreadable image") }
            case .pdf(let sha256):
                guard BackupPackage.digest(bytes) == sha256,
                      let pdf = PDFDocument(data: bytes), !pdf.isLocked, pdf.pageCount > 0 else {
                    throw BackupError.invalidPackage("damaged sealed PDF")
                }
            }
        }
    }

    static func snapshotJob(_ snapshot: ReportSnapshot) throws -> JobRecord {
        JobRecord(id: snapshot.jobID, customerName: snapshot.customerName, customerPhone: snapshot.customerPhone,
                  customerEmail: snapshot.customerEmail, vehicleLabel: snapshot.vehicleLabel, plate: snapshot.plate,
                  color: snapshot.color, serviceName: snapshot.serviceName, notes: snapshot.notes,
                  location: snapshot.serviceLocation, createdAt: snapshot.createdAt,
                  captureData: try JSONEncoder().encode(snapshot.capture),
                  acknowledgmentData: try JSONEncoder().encode(snapshot.acknowledgment),
                  serviceStartedAt: snapshot.serviceStartedAt, serviceFinishedAt: snapshot.serviceFinishedAt)
    }

    private mutating func addCapture(_ capture: CaptureDocument) throws {
        guard capture.slots.allSatisfy({ !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              capture.skips.allSatisfy({ !$0.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw BackupError.invalidPackage("blank capture slot or skip reason")
        }
        for photo in capture.photos {
            try add(photo.imagePath, kind: .image)
            try add(photo.thumbnailPath, kind: .image)
        }
    }

    private mutating func add(_ path: String, kind: AssetKind) throws {
        try BackupPackage.validatePath(path)
        if let existing = assets[path], existing != kind { throw BackupError.invalidPackage("conflicting asset roles") }
        assets[path] = kind
    }

    private func validateDigest(_ digest: String) throws {
        guard digest.count == 64, digest.allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
            throw BackupError.invalidPackage("malformed acknowledgment digest")
        }
    }
}
