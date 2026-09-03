import Foundation
import SwiftData

@Model
final class BusinessProfile {
    @Attribute(.unique) var id: UUID
    var businessName: String
    var phone: String
    var email: String
    var disclaimer: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        businessName: String = "",
        phone: String = "",
        email: String = "",
        disclaimer: String = "This report records visible vehicle condition and the services selected at the time shown. It is not insurance, a warranty, or a guarantee.",
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.businessName = businessName
        self.phone = phone
        self.email = email
        self.disclaimer = disclaimer
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}
