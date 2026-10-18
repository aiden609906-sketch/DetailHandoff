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

    func record(for job: JobRecord, stage: AcknowledgmentStage = .preService) throws -> AcknowledgmentRecord? {
        guard let data = data(for: job, stage: stage) else { return nil }
        do {
            let record = try JSONDecoder().decode(AcknowledgmentRecord.self, from: data)
            try validate(record, stage: stage)
            return record
        } catch let error as AcknowledgmentRepositoryError {
            throw error
        } catch {
            throw AcknowledgmentRepositoryError.corruptRecord
        }
    }

    func sign(job: JobRecord, stage: AcknowledgmentStage = .preService, name: String, strokes: [SignatureStroke]) throws {
        try validateMutable(job)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw AcknowledgmentRepositoryError.blankCustomerName }
        try validateSignature(strokes)
        try save(
            AcknowledgmentRecord(
                method: .signature,
                customerName: trimmedName,
                recordedAt: Date(),
                confirmationText: stage.confirmationText,
                unavailableReason: "",
                strokes: strokes,
                contentDigest: try contentDigest(for: job, stage: stage),
                contentDigestVersion: 2
            ),
            on: job,
            stage: stage
        )
    }

    func markUnavailable(job: JobRecord, stage: AcknowledgmentStage = .preService, reason: String) throws {
        try validateMutable(job)
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else { throw AcknowledgmentRepositoryError.blankUnavailableReason }
        try save(
            AcknowledgmentRecord(
                method: .customerUnavailable,
                customerName: job.customerName.trimmingCharacters(in: .whitespacesAndNewlines),
                recordedAt: Date(),
                confirmationText: stage.confirmationText,
                unavailableReason: trimmedReason,
                strokes: [],
                contentDigest: try contentDigest(for: job, stage: stage),
                contentDigestVersion: 2
            ),
            on: job,
            stage: stage
        )
    }

    func isCurrent(job: JobRecord, stage: AcknowledgmentStage = .preService) throws -> Bool {
        guard let record = try record(for: job, stage: stage) else { return false }
        return record.contentDigest == (try contentDigest(for: job, stage: stage))
    }

    private func contentDigest(for job: JobRecord, stage: AcknowledgmentStage) throws -> String {
        let document = try captureRepository.document(for: job)
        return switch stage {
        case .preService: try AcknowledgmentContentDigest.make(for: job, document: document)
        case .completion: try CompletionAcknowledgmentContentDigest.make(for: job, document: document)
        }
    }

    private func save(_ record: AcknowledgmentRecord, on job: JobRecord, stage: AcknowledgmentStage) throws {
        let previousData = data(for: job, stage: stage)
        let previousUpdatedAt = job.updatedAt
        setData(try JSONEncoder().encode(record), on: job, stage: stage)
        job.updatedAt = Date()
        do {
            try saveChanges()
        } catch {
            setData(previousData, on: job, stage: stage)
            job.updatedAt = previousUpdatedAt
            throw error
        }
    }

    private func validateMutable(_ job: JobRecord) throws {
        guard job.modelContext === context, !job.isDeleted, job.deletedAt == nil else { throw AcknowledgmentRepositoryError.immutableJob }
        guard job.status != .finalized, job.status != .archived else {
            throw AcknowledgmentRepositoryError.immutableJob
        }
    }

    private func validate(_ record: AcknowledgmentRecord, stage: AcknowledgmentStage) throws {
        guard record.contentDigestVersion == nil || record.contentDigestVersion == 2 else {
            throw AcknowledgmentRepositoryError.corruptRecord
        }
        guard record.confirmationText == stage.confirmationText, !record.contentDigest.isEmpty else {
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

    private func data(for job: JobRecord, stage: AcknowledgmentStage) -> Data? {
        stage == .preService ? job.acknowledgmentData : job.completionAcknowledgmentData
    }

    private func setData(_ data: Data?, on job: JobRecord, stage: AcknowledgmentStage) {
        if stage == .preService { job.acknowledgmentData = data }
        else { job.completionAcknowledgmentData = data }
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
