import Foundation

enum NewJobValidationError: Error, Equatable, LocalizedError {
    case missingVehicle
    case missingService

    var errorDescription: String? {
        switch self {
        case .missingVehicle:
            "Enter a vehicle before creating the job."
        case .missingService:
            "Enter a service before creating the job."
        }
    }
}

enum NewJobValidator {
    static func validate(vehicleLabel: String, serviceName: String) -> NewJobValidationError? {
        if vehicleLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .missingVehicle
        }

        if serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .missingService
        }

        return nil
    }
}
