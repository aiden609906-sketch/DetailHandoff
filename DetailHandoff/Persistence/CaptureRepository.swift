import Foundation
import SwiftData

enum CaptureRepositoryError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case immutableJob
    case unknownSlot(String)
    case blankSkipReason
    case unknownPhoto(UUID)
    case photoLinkedToFinding(UUID)
    case unknownFinding(UUID)
    case findingPhotoDoesNotBelongToSlot(UUID)
    case duplicateFindingPhoto(UUID)
}

@MainActor
final class CaptureRepository {
    private let context: ModelContext
    private let media: MediaStore
    private let saveChanges: () throws -> Void

    init(context: ModelContext, media: MediaStore) {
        self.context = context
        self.media = media
        self.saveChanges = { try context.save() }
    }

    init(context: ModelContext, media: MediaStore, saveChanges: @escaping () throws -> Void) {
        self.context = context
        self.media = media
        self.saveChanges = saveChanges
    }

    func document(for job: JobRecord) throws -> CaptureDocument {
        guard let captureData = job.captureData else { return .empty }
        let document = try JSONDecoder().decode(CaptureDocument.self, from: captureData)
        guard document.schemaVersion == CaptureDocument.currentSchemaVersion else {
            throw CaptureRepositoryError.unsupportedSchemaVersion(document.schemaVersion)
        }
        return document
    }

    func addPhoto(to job: JobRecord, data: Data, slotID: String, phase: CapturePhase) throws {
        var document = try document(for: job)
        try validateMutable(job)
        try validateSlot(slotID, in: document)
        let stored = try media.storeImage(data, jobID: job.id)
        document.photos.append(CapturedPhoto(slotID: slotID, phase: phase, imagePath: stored.imagePath, thumbnailPath: stored.thumbnailPath))
        do {
            try save(document, on: job)
        } catch {
            try? media.remove(stored)
            throw error
        }
    }

    func removePhoto(from job: JobRecord, photoID: UUID) throws {
        var document = try document(for: job)
        try validateMutable(job)
        guard let index = document.photos.firstIndex(where: { $0.id == photoID }) else { throw CaptureRepositoryError.unknownPhoto(photoID) }
        guard !document.findings.contains(where: { $0.photoIDs.contains(photoID) }) else {
            throw CaptureRepositoryError.photoLinkedToFinding(photoID)
        }
        let removed = document.photos.remove(at: index)
        try save(document, on: job)
        let stillReferenced = document.photos.contains { $0.imagePath == removed.imagePath || $0.thumbnailPath == removed.thumbnailPath }
        if !stillReferenced { try media.remove(StoredImage(imagePath: removed.imagePath, thumbnailPath: removed.thumbnailPath)) }
    }

    func setSkip(on job: JobRecord, slotID: String, phase: CapturePhase, reason: String) throws {
        var document = try document(for: job)
        try validateMutable(job)
        try validateSlot(slotID, in: document)
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else { throw CaptureRepositoryError.blankSkipReason }
        document.skips.removeAll { $0.slotID == slotID && $0.phase == phase }
        document.skips.append(CaptureSkip(slotID: slotID, phase: phase, reason: trimmedReason))
        try save(document, on: job)
    }

    func clearSkip(on job: JobRecord, slotID: String, phase: CapturePhase) throws {
        var document = try document(for: job)
        try validateMutable(job)
        try validateSlot(slotID, in: document)
        document.skips.removeAll { $0.slotID == slotID && $0.phase == phase }
        try save(document, on: job)
    }

    func saveFinding(on job: JobRecord, finding: VehicleFinding) throws {
        var document = try document(for: job)
        try validateMutable(job)
        try validateSlot(finding.slotID, in: document)
        try validatePhotoOwnership(of: finding, in: document)
        if let index = document.findings.firstIndex(where: { $0.id == finding.id }) {
            document.findings[index] = finding
        } else {
            document.findings.append(finding)
        }
        try save(document, on: job)
    }

    func removeFinding(from job: JobRecord, findingID: UUID) throws {
        var document = try document(for: job)
        try validateMutable(job)
        guard let index = document.findings.firstIndex(where: { $0.id == findingID }) else { throw CaptureRepositoryError.unknownFinding(findingID) }
        document.findings.remove(at: index)
        try save(document, on: job)
    }

    private func save(_ document: CaptureDocument, on job: JobRecord) throws {
        let previousData = job.captureData
        let previousUpdatedAt = job.updatedAt
        let encoded = try JSONEncoder().encode(document)
        job.captureData = encoded
        job.updatedAt = Date()
        do {
            try saveChanges()
        } catch {
            job.captureData = previousData
            job.updatedAt = previousUpdatedAt
            throw error
        }
    }

    private func validateMutable(_ job: JobRecord) throws {
        guard job.status != .finalized, job.status != .archived else { throw CaptureRepositoryError.immutableJob }
    }

    private func validateSlot(_ slotID: String, in document: CaptureDocument) throws {
        guard document.slots.contains(where: { $0.id == slotID }) else { throw CaptureRepositoryError.unknownSlot(slotID) }
    }

    private func validatePhotoOwnership(of finding: VehicleFinding, in document: CaptureDocument) throws {
        var seenPhotoIDs = Set<UUID>()
        for photoID in finding.photoIDs {
            guard seenPhotoIDs.insert(photoID).inserted else { throw CaptureRepositoryError.duplicateFindingPhoto(photoID) }
            guard document.photos.contains(where: { $0.id == photoID && $0.slotID == finding.slotID }) else {
                throw CaptureRepositoryError.findingPhotoDoesNotBelongToSlot(photoID)
            }
        }
    }
}
