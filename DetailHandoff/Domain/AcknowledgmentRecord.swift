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
}

enum AcknowledgmentContentDigest {
    static func make(for job: JobRecord, document: CaptureDocument) throws -> String {
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
        let beforeSkips = document.skips
            .filter { $0.phase == .before }
            .map { PreServiceSkip(slotID: $0.slotID, reason: $0.reason) }
            .sorted { lhs, rhs in
                lhs.slotID == rhs.slotID ? lhs.reason < rhs.reason : lhs.slotID < rhs.slotID
            }
        let beforePhotoIDs = Set(document.photos.filter { $0.phase == .before }.map(\.id))
        let findings = document.findings
            .filter { !$0.photoIDs.isEmpty && $0.photoIDs.allSatisfy(beforePhotoIDs.contains) }
            .map {
                PreServiceFinding(
                    id: $0.id.uuidString,
                    slotID: $0.slotID,
                    kind: $0.kind,
                    severity: $0.severity,
                    notes: $0.notes,
                    photoIDs: $0.photoIDs.map(\.uuidString).sorted()
                )
            }
            .sorted { lhs, rhs in
                lhs.slotID == rhs.slotID ? lhs.id < rhs.id : lhs.slotID < rhs.slotID
            }
        let content = PreServiceContent(
            jobID: job.id.uuidString,
            customerName: job.customerName,
            vehicleLabel: job.vehicleLabel,
            plate: job.plate,
            color: job.color,
            serviceName: job.serviceName,
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
