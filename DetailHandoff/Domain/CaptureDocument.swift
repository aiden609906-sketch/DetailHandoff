import Foundation

enum CapturePhase: String, Codable, CaseIterable { case before, after }

struct CaptureSlot: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var isRequired: Bool

    init(id: String, name: String, isRequired: Bool) {
        self.id = id
        self.name = name
        self.isRequired = isRequired
    }

    static var standard: [CaptureSlot] {
        [
            CaptureSlot(id: "front", name: "Front", isRequired: true),
            CaptureSlot(id: "rear", name: "Rear", isRequired: true),
            CaptureSlot(id: "driver-side", name: "Driver side", isRequired: true),
            CaptureSlot(id: "passenger-side", name: "Passenger side", isRequired: true),
            CaptureSlot(id: "front-bumper", name: "Front bumper", isRequired: true),
            CaptureSlot(id: "rear-bumper", name: "Rear bumper", isRequired: true),
            CaptureSlot(id: "hood-windshield", name: "Hood and windshield", isRequired: true),
            CaptureSlot(id: "wheels-tires", name: "Wheels and tires", isRequired: true),
            CaptureSlot(id: "front-seats", name: "Front seats", isRequired: true),
            CaptureSlot(id: "rear-seats", name: "Rear seats", isRequired: true),
            CaptureSlot(id: "dashboard-console", name: "Dashboard and console", isRequired: true),
            CaptureSlot(id: "trunk", name: "Trunk or cargo area", isRequired: true)
        ]
    }
}

struct CapturedPhoto: Codable, Equatable, Identifiable {
    var id: UUID
    var slotID: String
    var phase: CapturePhase
    var imagePath: String
    var thumbnailPath: String
    var capturedAt: Date

    init(id: UUID = UUID(), slotID: String, phase: CapturePhase, imagePath: String, thumbnailPath: String, capturedAt: Date = Date()) {
        self.id = id
        self.slotID = slotID
        self.phase = phase
        self.imagePath = imagePath
        self.thumbnailPath = thumbnailPath
        self.capturedAt = capturedAt
    }
}

struct CaptureSkip: Codable, Equatable {
    var slotID: String
    var phase: CapturePhase
    var reason: String

    init(slotID: String, phase: CapturePhase, reason: String) {
        self.slotID = slotID
        self.phase = phase
        self.reason = reason
    }
}

struct VehicleFinding: Codable, Equatable, Identifiable {
    var id: UUID
    var slotID: String
    var kind: String
    var severity: String
    var notes: String
    var photoIDs: [UUID]

    init(id: UUID = UUID(), slotID: String, kind: String, severity: String, notes: String, photoIDs: [UUID]) {
        self.id = id
        self.slotID = slotID
        self.kind = kind
        self.severity = severity
        self.notes = notes
        self.photoIDs = photoIDs
    }
}

struct CaptureDocument: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var slots: [CaptureSlot]
    var photos: [CapturedPhoto]
    var skips: [CaptureSkip]
    var findings: [VehicleFinding]

    init(
        schemaVersion: Int = CaptureDocument.currentSchemaVersion,
        slots: [CaptureSlot] = CaptureSlot.standard,
        photos: [CapturedPhoto] = [],
        skips: [CaptureSkip] = [],
        findings: [VehicleFinding] = []
    ) {
        self.schemaVersion = schemaVersion
        self.slots = slots
        self.photos = photos
        self.skips = skips
        self.findings = findings
    }

    static var empty: CaptureDocument { CaptureDocument() }
}
