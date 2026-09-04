import Foundation
import SwiftData

enum JobRepositoryError: Error, Equatable {
    case noNextStatus
    case incompleteCapture(phase: CapturePhase, missingSlots: [CaptureSlot])
    case corruptCapture(phase: CapturePhase)
}

@MainActor
final class JobRepository {
    private let context: ModelContext
    private let saveChanges: () throws -> Void
    private let media: MediaStore

    init(context: ModelContext) {
        self.context = context
        saveChanges = { try context.save() }
        media = MediaStore(root: MediaStore.defaultRoot)
    }

    init(context: ModelContext, saveChanges: @escaping () throws -> Void) {
        self.context = context
        self.saveChanges = saveChanges
        media = MediaStore(root: MediaStore.defaultRoot)
    }

    func createJob(
        customerName: String,
        vehicleLabel: String,
        plate: String,
        color: String,
        serviceName: String,
        notes: String
    ) throws -> JobRecord {
        let job = JobRecord(
            customerName: customerName.trimmingCharacters(in: .whitespacesAndNewlines),
            vehicleLabel: vehicleLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            plate: plate.trimmingCharacters(in: .whitespacesAndNewlines),
            color: color.trimmingCharacters(in: .whitespacesAndNewlines),
            serviceName: serviceName.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        context.insert(job)

        do {
            try saveChanges()
        } catch {
            context.delete(job)
            throw error
        }

        return job
    }

    func advance(_ job: JobRecord) throws {
        guard let nextStatus = job.status.next else {
            throw JobRepositoryError.noNextStatus
        }

        if let phase = capturePhaseRequiringCompletion(for: job.status) {
            let document: CaptureDocument
            do {
                document = try CaptureRepository(context: context, media: media).document(for: job)
            } catch {
                throw JobRepositoryError.corruptCapture(phase: phase)
            }
            let missingSlots = CaptureValidation.missingRequiredSlots(in: document, phase: phase)
            guard missingSlots.isEmpty else {
                throw JobRepositoryError.incompleteCapture(phase: phase, missingSlots: missingSlots)
            }
        }

        let previousStatus = job.status
        let previousUpdatedAt = job.updatedAt
        job.status = nextStatus
        job.updatedAt = Date()

        do {
            try saveChanges()
        } catch {
            job.status = previousStatus
            job.updatedAt = previousUpdatedAt
            throw error
        }
    }

    private func capturePhaseRequiringCompletion(for status: JobStatus) -> CapturePhase? {
        switch status {
        case .beforeCapture: .before
        case .afterCapture: .after
        default: nil
        }
    }

    func search(_ jobs: [JobRecord], query: String) -> [JobRecord] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return jobs
            .filter { job in
                guard job.deletedAt == nil else { return false }
                guard !trimmedQuery.isEmpty else { return true }

                return job.customerName.localizedCaseInsensitiveContains(trimmedQuery)
                    || job.vehicleLabel.localizedCaseInsensitiveContains(trimmedQuery)
                    || job.plate.localizedCaseInsensitiveContains(trimmedQuery)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
