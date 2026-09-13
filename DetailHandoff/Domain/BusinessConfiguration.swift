import Foundation

struct ServiceOption: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct CaptureTemplateOption: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var slots: [CaptureSlot]

    init(id: UUID = UUID(), name: String, slots: [CaptureSlot]) {
        self.id = id
        self.name = name
        self.slots = slots
    }
}

enum BusinessConfigurationError: Error, Equatable {
    case emptyServices
    case emptyTemplates
    case blankServiceName
    case blankTemplateName
    case invalidDefaultTemplate
    case emptyTemplateSlots
    case blankSlotID
    case duplicateSlotID(String)
}

struct BusinessConfiguration: Codable, Equatable {
    var services: [ServiceOption]
    var templates: [CaptureTemplateOption]
    var defaultTemplateID: UUID

    static let standard: BusinessConfiguration = {
        let template = CaptureTemplateOption(name: "Standard Detail", slots: CaptureSlot.standard)
        return BusinessConfiguration(
            services: [ServiceOption(name: "Full Detail"), ServiceOption(name: "Exterior Detail")],
            templates: [template],
            defaultTemplateID: template.id
        )
    }()

    func validated() throws -> BusinessConfiguration {
        guard !services.isEmpty else { throw BusinessConfigurationError.emptyServices }
        guard !templates.isEmpty else { throw BusinessConfigurationError.emptyTemplates }
        guard services.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw BusinessConfigurationError.blankServiceName
        }
        guard templates.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw BusinessConfigurationError.blankTemplateName
        }
        guard templates.contains(where: { $0.id == defaultTemplateID }) else {
            throw BusinessConfigurationError.invalidDefaultTemplate
        }
        for template in templates {
            guard !template.slots.isEmpty else { throw BusinessConfigurationError.emptyTemplateSlots }
            var slotIDs = Set<String>()
            for slot in template.slots {
                let id = slot.id.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !id.isEmpty else { throw BusinessConfigurationError.blankSlotID }
                guard slotIDs.insert(id).inserted else { throw BusinessConfigurationError.duplicateSlotID(id) }
            }
        }
        return self
    }

    /// Service order is the durable default: New Job preselects the first saved option.
    func makingServiceDefault(_ serviceID: UUID) -> BusinessConfiguration {
        guard let index = services.firstIndex(where: { $0.id == serviceID }) else { return self }
        var updated = self
        let selected = updated.services.remove(at: index)
        updated.services.insert(selected, at: 0)
        return updated
    }
}
