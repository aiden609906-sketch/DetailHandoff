import Foundation
import SwiftData

enum JobRepositoryError: Error, Equatable {
    case noNextStatus
}

@MainActor
final class JobRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
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
        try context.save()
        return job
    }

    func advance(_ job: JobRecord) throws {
        guard let nextStatus = job.status.next else {
            throw JobRepositoryError.noNextStatus
        }

        job.status = nextStatus
        try context.save()
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
