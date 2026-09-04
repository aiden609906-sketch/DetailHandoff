import Foundation
import SwiftData

@Model
final class JobRecord {
    @Attribute(.unique) var id: UUID
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

    var status: JobStatus {
        get { JobStatus(rawValue: statusRawValue) ?? .draft }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        customerName: String,
        customerPhone: String? = nil,
        customerEmail: String? = nil,
        vehicleLabel: String,
        plate: String,
        color: String,
        serviceName: String,
        notes: String,
        location: String? = nil,
        status: JobStatus = .draft,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        deletedAt: Date? = nil,
        captureData: Data? = nil,
        acknowledgmentData: Data? = nil,
        reportsData: Data? = nil,
        serviceStartedAt: Date? = nil,
        serviceFinishedAt: Date? = nil
    ) {
        self.id = id
        self.customerName = customerName
        self.customerPhone = customerPhone
        self.customerEmail = customerEmail
        self.vehicleLabel = vehicleLabel
        self.plate = plate
        self.color = color
        self.serviceName = serviceName
        self.notes = notes
        self.location = location
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.deletedAt = deletedAt
        self.captureData = captureData
        self.acknowledgmentData = acknowledgmentData
        self.reportsData = reportsData
        self.serviceStartedAt = serviceStartedAt
        self.serviceFinishedAt = serviceFinishedAt
    }
}
