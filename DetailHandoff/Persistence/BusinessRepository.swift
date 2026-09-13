import Foundation
import SwiftData

enum BusinessRepositoryError: Error, Equatable {
    case blankBusinessName
    case profileAlreadyExists
    case corruptConfiguration
}

@MainActor
final class BusinessRepository {
    private let context: ModelContext
    private let saveChanges: () throws -> Void
    private let media: MediaStore

    init(context: ModelContext, media: MediaStore = MediaStore(root: MediaStore.defaultRoot)) {
        self.context = context
        self.media = media
        saveChanges = { try context.save() }
    }

    init(
        context: ModelContext,
        media: MediaStore = MediaStore(root: MediaStore.defaultRoot),
        saveChanges: @escaping () throws -> Void
    ) {
        self.context = context
        self.media = media
        self.saveChanges = saveChanges
    }

    func createProfile(
        businessName: String,
        phone: String,
        email: String,
        configuration: BusinessConfiguration,
        logoData: Data? = nil
    ) throws -> BusinessProfile {
        let name = businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw BusinessRepositoryError.blankBusinessName }
        let validated = try configuration.validated()
        guard try context.fetch(FetchDescriptor<BusinessProfile>()).isEmpty else {
            throw BusinessRepositoryError.profileAlreadyExists
        }
        let configurationData = try JSONEncoder().encode(validated)
        let logoPath: String?
        if let logoData {
            logoPath = try media.storeBusinessLogo(logoData)
        } else {
            logoPath = nil
        }
        let profile = BusinessProfile(
            businessName: name,
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            logoImagePath: logoPath,
            configurationData: configurationData
        )
        context.insert(profile)
        do { try saveChanges() }
        catch {
            context.delete(profile)
            if let logoPath {
                try? media.removeAsset(at: logoPath)
            }
            throw error
        }
        return profile
    }

    func configuration(for profile: BusinessProfile) throws -> BusinessConfiguration {
        guard let data = profile.configurationData else { return .standard }
        do { return try JSONDecoder().decode(BusinessConfiguration.self, from: data).validated() }
        catch let error as BusinessConfigurationError { throw error }
        catch { throw BusinessRepositoryError.corruptConfiguration }
    }

    func updateDetails(_ profile: BusinessProfile, businessName: String, phone: String, email: String, disclaimer: String, configuration: BusinessConfiguration) throws {
        let name = businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw BusinessRepositoryError.blankBusinessName }
        let configurationData = try JSONEncoder().encode(configuration.validated())
        let oldName = profile.businessName
        let oldPhone = profile.phone
        let oldEmail = profile.email
        let oldDisclaimer = profile.disclaimer
        let oldConfigurationData = profile.configurationData
        let oldUpdatedAt = profile.updatedAt
        profile.businessName = name
        profile.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.disclaimer = disclaimer.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.configurationData = configurationData
        profile.updatedAt = Date()
        do { try saveChanges() }
        catch {
            profile.businessName = oldName
            profile.phone = oldPhone
            profile.email = oldEmail
            profile.disclaimer = oldDisclaimer
            profile.configurationData = oldConfigurationData
            profile.updatedAt = oldUpdatedAt
            throw error
        }
    }

    func importLogo(_ data: Data, for profile: BusinessProfile) throws {
        let path = try media.storeBusinessLogo(data)
        let oldPath = profile.logoImagePath
        let oldUpdatedAt = profile.updatedAt
        profile.logoImagePath = path
        profile.updatedAt = Date()
        do { try saveChanges() }
        catch {
            profile.logoImagePath = oldPath
            profile.updatedAt = oldUpdatedAt
            try? media.removeAsset(at: path)
            throw error
        }
    }
}
