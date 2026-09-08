import CryptoKit
import Foundation

enum AcknowledgmentMethod: String, Codable {
    case signature
    case customerUnavailable
}

struct SignaturePoint: Codable, Equatable {
    var x: Double
    var y: Double
}

struct SignatureStroke: Codable, Equatable {
    var points: [SignaturePoint]
}

struct AcknowledgmentRecord: Codable, Equatable {
    static let confirmationText = "I have reviewed the visible vehicle condition and the selected services recorded here before work begins."

    var method: AcknowledgmentMethod
    var customerName: String
    var recordedAt: Date
    var confirmationText: String
    var unavailableReason: String
    var strokes: [SignatureStroke]
    var contentDigest: String
    // Absent in legacy records. Version 2 includes the Before portion of mixed-phase findings.
    var contentDigestVersion: Int? = nil
}

enum AcknowledgmentContentDigest {
    static func make(for job: JobRecord, document: CaptureDocument) throws -> String {
        try make(for: job, document: document, includesMixedFindings: true)
    }

    /// Historical snapshots keep the scope actually acknowledged at the time they were sealed.
    /// Never use the legacy scope to authorize mutable jobs or new seals.
    static func makeForFrozenRecord(_ record: AcknowledgmentRecord, job: JobRecord, document: CaptureDocument) throws -> String {
        try make(for: job, document: document, includesMixedFindings: record.contentDigestVersion == 2)
    }

    private static func make(for job: JobRecord, document: CaptureDocument, includesMixedFindings: Bool) throws -> String {
        let beforePhotos = document.photos
            .filter { $0.phase == .before }
            .map {
                PreServicePhoto(
                    id: $0.id.uuidString,
                    slotID: $0.slotID,
                    imagePath: $0.imagePath,
                    thumbnailPath: $0.thumbnailPath,
                    capturedAt: $0.capturedAt.timeIntervalSince1970
                )
            }
            .sorted { lhs, rhs in
                if lhs.slotID != rhs.slotID { return lhs.slotID < rhs.slotID }
                if lhs.capturedAt != rhs.capturedAt { return lhs.capturedAt < rhs.capturedAt }
                return lhs.id < rhs.id
            }
        var beforeSkips: [PreServiceSkip] = []
        var beforePhotoIDs = Set<UUID>()
        for photo in document.photos where photo.phase == .before {
            beforePhotoIDs.insert(photo.id)
        }
        for skip in document.skips where skip.phase == .before {
            beforeSkips.append(PreServiceSkip(slotID: skip.slotID, reason: skip.reason))
        }
        beforeSkips.sort { lhs, rhs in
            lhs.slotID == rhs.slotID ? lhs.reason < rhs.reason : lhs.slotID < rhs.slotID
        }

        var findings: [PreServiceFinding] = []
        for finding in document.findings {
            let linkedBeforeIDs = finding.photoIDs.filter { beforePhotoIDs.contains($0) }
            guard !linkedBeforeIDs.isEmpty else { continue }
            if !includesMixedFindings, linkedBeforeIDs.count != finding.photoIDs.count { continue }
            let photoIDs = linkedBeforeIDs.map(\.uuidString).sorted()
            findings.append(
                PreServiceFinding(
                    id: finding.id.uuidString,
                    slotID: finding.slotID,
                    kind: finding.kind,
                    severity: finding.severity,
                    notes: finding.notes,
                    photoIDs: photoIDs
                )
            )
        }
        findings.sort { lhs, rhs in
            lhs.slotID == rhs.slotID ? lhs.id < rhs.id : lhs.slotID < rhs.slotID
        }
        let content = PreServiceContent(
            jobID: job.id.uuidString,
            customerName: job.customerName,
            vehicleLabel: job.vehicleLabel,
            plate: job.plate,
            color: job.color,
            serviceName: job.serviceName,
            customerPhone: job.customerPhone,
            customerEmail: job.customerEmail,
            serviceLocation: job.location,
            beforePhotos: beforePhotos,
            beforeSkips: beforeSkips,
            findings: findings
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(content)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct PreServiceContent: Codable {
    var jobID: String
    var customerName: String
    var vehicleLabel: String
    var plate: String
    var color: String
    var serviceName: String
    var customerPhone: String?
    var customerEmail: String?
    var serviceLocation: String?
    var beforePhotos: [PreServicePhoto]
    var beforeSkips: [PreServiceSkip]
    var findings: [PreServiceFinding]
}

private struct PreServicePhoto: Codable {
    var id: String
    var slotID: String
    var imagePath: String
    var thumbnailPath: String
    var capturedAt: TimeInterval
}

private struct PreServiceSkip: Codable {
    var slotID: String
    var reason: String
}

private struct PreServiceFinding: Codable {
    var id: String
    var slotID: String
    var kind: String
    var severity: String
    var notes: String
    var photoIDs: [String]
}
