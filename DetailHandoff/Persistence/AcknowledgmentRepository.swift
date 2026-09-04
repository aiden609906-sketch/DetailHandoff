import Foundation
import SwiftData

enum AcknowledgmentRepositoryError: Error, Equatable {
    case immutableJob
    case blankCustomerName
    case blankUnavailableReason
    case emptySignature
    case invalidSignaturePoint
    case corruptRecord
}

@MainActor
final class AcknowledgmentRepository {
    private let context: ModelContext
    private let saveChanges: () throws -> Void
    private let captureRepository: CaptureRepository

    init(context: ModelContext) {
        self.context = context
        saveChanges = { try context.save() }
        captureRepository = CaptureRepository(context: context, media: MediaStore(root: MediaStore.defaultRoot))
    }

    init(context: ModelContext, saveChanges: @escaping () throws -> Void) {
        self.context = context
        self.saveChanges = saveChanges
        captureRepository = CaptureRepository(context: context, media: MediaStore(root: MediaStore.defaultRoot))
    }

    func record(for job: JobRecord) throws -> AcknowledgmentRecord? {
        guard let data = job.acknowledgmentData else { return nil }
        do {
            let record = try JSONDecoder().decode(AcknowledgmentRecord.self, from: data)
            try validate(record)
            return record
        } catch let error as AcknowledgmentRepositoryError {
            throw error
        } catch {
            throw AcknowledgmentRepositoryError.corruptRecord
        }
    }

    func sign(job: JobRecord, name: String, strokes: [SignatureStroke]) throws {
        try validateMutable(job)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw AcknowledgmentRepositoryError.blankCustomerName }
        try validateSignature(strokes)
        try save(
            AcknowledgmentRecord(
                method: .signature,
                customerName: trimmedName,
                recordedAt: Date(),
                confirmationText: AcknowledgmentRecord.confirmationText,
                unavailableReason: "",
                strokes: strokes,
                contentDigest: try contentDigest(for: job)
            ),
            on: job
        )
    }

    func markUnavailable(job: JobRecord, reason: String) throws {
        try validateMutable(job)
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else { throw AcknowledgmentRepositoryError.blankUnavailableReason }
        try save(
            AcknowledgmentRecord(
                method: .customerUnavailable,
                customerName: job.customerName.trimmingCharacters(in: .whitespacesAndNewlines),
                recordedAt: Date(),
                confirmationText: AcknowledgmentRecord.confirmationText,
                unavailableReason: trimmedReason,
                strokes: [],
                contentDigest: try contentDigest(for: job)
            ),
            on: job
        )
    }

    func isCurrent(job: JobRecord) throws -> Bool {
        guard let record = try record(for: job) else { return false }
        return record.contentDigest == (try contentDigest(for: job))
    }

    private func contentDigest(for job: JobRecord) throws -> String {
        try AcknowledgmentContentDigest.make(for: job, document: captureRepository.document(for: job))
    }

    private func save(_ record: AcknowledgmentRecord, on job: JobRecord) throws {
        let previousData = job.acknowledgmentData
        let previousUpdatedAt = job.updatedAt
        job.acknowledgmentData = try JSONEncoder().encode(record)
        job.updatedAt = Date()
        do {
            try saveChanges()
        } catch {
            job.acknowledgmentData = previousData
            job.updatedAt = previousUpdatedAt
            throw error
        }
    }

    private func validateMutable(_ job: JobRecord) throws {
        guard job.status != .finalized, job.status != .archived else {
            throw AcknowledgmentRepositoryError.immutableJob
        }
    }

    private func validate(_ record: AcknowledgmentRecord) throws {
        guard record.confirmationText == AcknowledgmentRecord.confirmationText, !record.contentDigest.isEmpty else {
            throw AcknowledgmentRepositoryError.corruptRecord
        }
        switch record.method {
        case .signature:
            guard !record.customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  record.unavailableReason.isEmpty else {
                throw AcknowledgmentRepositoryError.corruptRecord
            }
            do {
                try validateSignature(record.strokes)
            } catch {
                throw AcknowledgmentRepositoryError.corruptRecord
            }
        case .customerUnavailable:
            guard !record.unavailableReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  record.strokes.isEmpty else {
                throw AcknowledgmentRepositoryError.corruptRecord
            }
        }
    }

    private func validateSignature(_ strokes: [SignatureStroke]) throws {
        var hasVisibleLine = false
        for stroke in strokes {
            for point in stroke.points {
                guard point.x.isFinite, point.y.isFinite,
                      (0...1).contains(point.x), (0...1).contains(point.y) else {
                    throw AcknowledgmentRepositoryError.invalidSignaturePoint
                }
            }
            guard stroke.points.count >= 2 else { continue }
            for (start, end) in zip(stroke.points, stroke.points.dropFirst()) {
                let dx = end.x - start.x
                let dy = end.y - start.y
                if (dx * dx + dy * dy).squareRoot() >= 0.002 {
                    hasVisibleLine = true
                }
            }
        }
        guard hasVisibleLine else { throw AcknowledgmentRepositoryError.emptySignature }
    }
}
