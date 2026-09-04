import Foundation
import SwiftData

enum JobRepositoryError: Error, Equatable {
    case noNextStatus
    case incompleteCapture(phase: CapturePhase, missingSlots: [CaptureSlot])
    case corruptCapture(phase: CapturePhase)
    case missingAcknowledgment
    case staleAcknowledgment
    case corruptAcknowledgment
    case reportSealRequired
    case immutableJob
    case blankVehicle
    case blankService
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
        notes: String,
        customerPhone: String? = nil,
        customerEmail: String? = nil,
        location: String? = nil,
        template: CaptureTemplateOption? = nil
    ) throws -> JobRecord {
        let job = JobRecord(
            customerName: customerName.trimmingCharacters(in: .whitespacesAndNewlines),
            customerPhone: normalizedOptional(customerPhone),
            customerEmail: normalizedOptional(customerEmail),
            vehicleLabel: vehicleLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            plate: plate.trimmingCharacters(in: .whitespacesAndNewlines),
            color: color.trimmingCharacters(in: .whitespacesAndNewlines),
            serviceName: serviceName.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            location: normalizedOptional(location),
            captureData: try template.map { try JSONEncoder().encode(CaptureDocument(slots: $0.slots)) }
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

    func updateDetails(
        _ job: JobRecord,
        customerName: String,
        customerPhone: String?,
        customerEmail: String?,
        vehicleLabel: String,
        plate: String,
        color: String,
        serviceName: String,
        location: String?,
        notes: String
    ) throws {
        guard job.status != .finalized, job.status != .archived else { throw JobRepositoryError.immutableJob }
        let vehicle = vehicleLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !vehicle.isEmpty else { throw JobRepositoryError.blankVehicle }
        guard !service.isEmpty else { throw JobRepositoryError.blankService }
        let oldCustomerName = job.customerName
        let oldCustomerPhone = job.customerPhone
        let oldCustomerEmail = job.customerEmail
        let oldVehicleLabel = job.vehicleLabel
        let oldPlate = job.plate
        let oldColor = job.color
        let oldServiceName = job.serviceName
        let oldLocation = job.location
        let oldNotes = job.notes
        let oldUpdatedAt = job.updatedAt
        job.customerName = customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        job.customerPhone = normalizedOptional(customerPhone)
        job.customerEmail = normalizedOptional(customerEmail)
        job.vehicleLabel = vehicle
        job.plate = plate.trimmingCharacters(in: .whitespacesAndNewlines)
        job.color = color.trimmingCharacters(in: .whitespacesAndNewlines)
        job.serviceName = service
        job.location = normalizedOptional(location)
        job.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        job.updatedAt = Date()
        do { try saveChanges() }
        catch {
            job.customerName = oldCustomerName
            job.customerPhone = oldCustomerPhone
            job.customerEmail = oldCustomerEmail
            job.vehicleLabel = oldVehicleLabel
            job.plate = oldPlate
            job.color = oldColor
            job.serviceName = oldServiceName
            job.location = oldLocation
            job.notes = oldNotes
            job.updatedAt = oldUpdatedAt
            throw error
        }
    }

    func advance(_ job: JobRecord) throws {
        guard job.status != .review else { throw JobRepositoryError.reportSealRequired }
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

        if job.status == .awaitingAcknowledgment {
            do {
                guard try AcknowledgmentRepository(context: context).record(for: job) != nil else {
                    throw JobRepositoryError.missingAcknowledgment
                }
                guard try AcknowledgmentRepository(context: context).isCurrent(job: job) else {
                    throw JobRepositoryError.staleAcknowledgment
                }
            } catch let error as JobRepositoryError {
                throw error
            } catch {
                throw JobRepositoryError.corruptAcknowledgment
            }
        }

        let previousStatus = job.status
        let previousUpdatedAt = job.updatedAt
        let previousServiceStartedAt = job.serviceStartedAt
        let previousServiceFinishedAt = job.serviceFinishedAt
        job.status = nextStatus
        job.updatedAt = Date()
        if nextStatus == .inProgress { job.serviceStartedAt = Date() }
        if nextStatus == .afterCapture { job.serviceFinishedAt = Date() }

        do {
            try saveChanges()
        } catch {
            job.status = previousStatus
            job.updatedAt = previousUpdatedAt
            job.serviceStartedAt = previousServiceStartedAt
            job.serviceFinishedAt = previousServiceFinishedAt
            throw error
        }
    }

    private func capturePhaseRequiringCompletion(for status: JobStatus) -> CapturePhase? {
        switch status {
        case .beforeCapture, .awaitingAcknowledgment: .before
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
                    || localDateKey(for: job.createdAt) == trimmedQuery
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func normalizedOptional(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func localDateKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
