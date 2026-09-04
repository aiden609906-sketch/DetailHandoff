import Foundation

struct BackupAsset: Codable, Equatable {
    var relativePath: String
    var byteCount: Int
    var sha256: String
}

struct BackupManifest: Codable, Equatable {
    var schemaVersion = 1
    var createdAt: Date
    var profile: BackupProfileDTO
    var jobs: [BackupJobDTO]
    var assets: [BackupAsset]
}

/// Optional payloads remain optional, including legacy nil configuration/capture/history.
struct BackupProfileDTO: Codable, Equatable {
    var id: UUID
    var businessName: String
    var phone: String
    var email: String
    var disclaimer: String
    var logoImagePath: String?
    var configurationData: Data?
    var reportNumberLedgerData: Data?
    var createdAt: Date
    var updatedAt: Date

    @MainActor
    init(_ profile: BusinessProfile) {
        id = profile.id
        businessName = profile.businessName
        phone = profile.phone
        email = profile.email
        disclaimer = profile.disclaimer
        logoImagePath = profile.logoImagePath
        configurationData = profile.configurationData
        reportNumberLedgerData = profile.reportNumberLedgerData
        createdAt = profile.createdAt
        updatedAt = profile.updatedAt
    }

    @MainActor
    func makeModel() -> BusinessProfile {
        let profile = BusinessProfile(id: id)
        apply(to: profile)
        return profile
    }

    @MainActor
    func apply(to profile: BusinessProfile) {
        profile.businessName = businessName
        profile.phone = phone
        profile.email = email
        profile.disclaimer = disclaimer
        profile.logoImagePath = logoImagePath
        profile.configurationData = configurationData
        profile.reportNumberLedgerData = reportNumberLedgerData
        profile.createdAt = createdAt
        profile.updatedAt = updatedAt
    }
}

struct BackupJobDTO: Codable, Equatable {
    var id: UUID
    var customerName: String
    var customerPhone: String?
    var customerEmail: String?
    var vehicleLabel: String
    var plate: String
    var color: String
    var serviceName: String
    var notes: String
    var location: String?
    var statusRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var captureData: Data?
    var acknowledgmentData: Data?
    var reportsData: Data?
    var serviceStartedAt: Date?
    var serviceFinishedAt: Date?

    @MainActor
    init(_ job: JobRecord) {
        id = job.id
        customerName = job.customerName
        customerPhone = job.customerPhone
        customerEmail = job.customerEmail
        vehicleLabel = job.vehicleLabel
        plate = job.plate
        color = job.color
        serviceName = job.serviceName
        notes = job.notes
        location = job.location
        statusRawValue = job.statusRawValue
        createdAt = job.createdAt
        updatedAt = job.updatedAt
        deletedAt = job.deletedAt
        captureData = job.captureData
        acknowledgmentData = job.acknowledgmentData
        reportsData = job.reportsData
        serviceStartedAt = job.serviceStartedAt
        serviceFinishedAt = job.serviceFinishedAt
    }

    @MainActor
    func makeModel() -> JobRecord {
        let job = JobRecord(id: id, customerName: customerName, vehicleLabel: vehicleLabel, plate: plate, color: color, serviceName: serviceName, notes: notes)
        apply(to: job)
        return job
    }

    @MainActor
    func apply(to job: JobRecord) {
        job.customerName = customerName
        job.customerPhone = customerPhone
        job.customerEmail = customerEmail
        job.vehicleLabel = vehicleLabel
        job.plate = plate
        job.color = color
        job.serviceName = serviceName
        job.notes = notes
        job.location = location
        job.statusRawValue = statusRawValue
        job.createdAt = createdAt
        job.updatedAt = updatedAt
        job.deletedAt = deletedAt
        job.captureData = captureData
        job.acknowledgmentData = acknowledgmentData
        job.reportsData = reportsData
        job.serviceStartedAt = serviceStartedAt
        job.serviceFinishedAt = serviceFinishedAt
    }
}

struct PhotoExportManifest: Codable {
    var schemaVersion = 1
    var jobID: UUID
    var vehicleLabel: String
    var photos: [PhotoExportEntry]
}

struct PhotoExportEntry: Codable {
    var photoID: UUID
    var phase: CapturePhase
    var slotID: String
    var slotName: String
    var capturedAt: Date
    var filename: String
    var sha256: String
}
