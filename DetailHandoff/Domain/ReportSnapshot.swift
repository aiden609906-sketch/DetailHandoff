import Foundation

/// Value-only content captured at sealing. Never rebuild a historical version from live models.
struct ReportSnapshot: Codable, Equatable {
    var jobID: UUID
    var businessName: String
    var businessPhone: String
    var businessEmail: String
    var logoImagePath: String?
    var disclaimer: String
    var customerName: String
    var vehicleLabel: String
    var plate: String
    var color: String
    var serviceName: String
    var notes: String
    var customerPhone: String? = nil
    var customerEmail: String? = nil
    var serviceLocation: String? = nil
    var createdAt: Date
    var serviceStartedAt: Date?
    var serviceFinishedAt: Date?
    var capture: CaptureDocument
    var acknowledgment: AcknowledgmentRecord

    @MainActor
    init(job: JobRecord, business: BusinessProfile, capture: CaptureDocument, acknowledgment: AcknowledgmentRecord) {
        jobID = job.id
        businessName = business.businessName
        businessPhone = business.phone
        businessEmail = business.email
        logoImagePath = business.logoImagePath
        disclaimer = business.disclaimer
        customerName = job.customerName
        vehicleLabel = job.vehicleLabel
        plate = job.plate
        color = job.color
        serviceName = job.serviceName
        notes = job.notes
        customerPhone = job.customerPhone
        customerEmail = job.customerEmail
        serviceLocation = job.location
        createdAt = job.createdAt
        serviceStartedAt = job.serviceStartedAt
        serviceFinishedAt = job.serviceFinishedAt
        self.capture = capture
        self.acknowledgment = acknowledgment
    }

    /// Unlinked originals, thumbnails and logos must remain available for report history/backups.
    var referencedAssetPaths: Set<String> {
        var paths = Set(capture.photos.flatMap { [$0.imagePath, $0.thumbnailPath] })
        if let logoImagePath { paths.insert(logoImagePath) }
        return paths
    }
}
