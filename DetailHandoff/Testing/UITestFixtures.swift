#if DEBUG
import Foundation
import SwiftData
import UIKit

@MainActor
enum UITestFixtures {
    private enum FixtureError: Error {
        case unknownFixture
        case missingPhoto(String)
    }
    private static let fixtureArgument = "--screenshot-fixture"
    private static let startupFailureArgument = "--startup-failure"
    private static let preserveStoreArgument = "--ui-testing-preserve-store"
    private static var didPrepareStore = false
    private static var didFailStartup = false

    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }

    nonisolated static var mediaRoot: URL? {
        guard isEnabled else { return nil }
        return root.appendingPathComponent("CaptureMedia", isDirectory: true)
    }

    static func makeContainer() throws -> ModelContainer? {
        guard isEnabled else { return nil }
        if ProcessInfo.processInfo.arguments.contains(startupFailureArgument), !didFailStartup {
            didFailStartup = true
            throw CocoaError(.fileReadCorruptFile)
        }
        if !didPrepareStore {
            if ProcessInfo.processInfo.arguments.contains(preserveStoreArgument) {
                let store = root.appendingPathComponent("DetailHandoffUITests.store")
                guard FileManager.default.fileExists(atPath: store.path) else {
                    throw CocoaError(.fileNoSuchFile)
                }
            } else {
                try prepareStore()
            }
            didPrepareStore = true
        }

        let container = try ModelContainer(
            for: BusinessProfile.self,
            JobRecord.self,
            configurations: ModelConfiguration(url: root.appendingPathComponent("DetailHandoffUITests.store"))
        )
        try installRequestedFixture(in: container)
        return container
    }

    private nonisolated static var root: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DetailHandoffUITests", isDirectory: true)
    }

    private static var requestedFixture: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: fixtureArgument), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func prepareStore() throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: root.path) {
            try manager.removeItem(at: root)
        }
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private static func installRequestedFixture(in container: ModelContainer) throws {
        guard let requestedFixture else { return }
        let context = container.mainContext
        let media = MediaStore(root: root.appendingPathComponent("CaptureMedia", isDirectory: true))
        let business = BusinessRepository(context: context, media: media)
        let profile = try business.createProfile(
            businessName: "Northline Detail Studio",
            phone: "555-0100",
            email: "fixtures@example.test",
            configuration: .standard
        )

        switch requestedFixture {
        case "complete":
            let captureJob = try makeCaptureFixture(in: context, media: media)
            let completeJob = try makeReviewReadyJob(
                vehicle: "Silver Sedan",
                customer: "Alex Morgan",
                in: context,
                media: media
            )
            let fixtureDate = Date(timeIntervalSince1970: 1_700_000_000)
            captureJob.createdAt = fixtureDate
            completeJob.createdAt = fixtureDate.addingTimeInterval(60)
            try context.save()
        case "revision":
            let job = try makeReviewReadyJob(
                vehicle: "Revision Fixture SUV",
                customer: "Morgan Fixture",
                in: context,
                media: media
            )
            _ = try ReportRepository(context: context, media: media).seal(job: job, business: profile)
        case "trash":
            let job = try makeJob(
                vehicle: "Trash Fixture Hatchback",
                customer: "Jordan Fixture",
                in: context
            )
            try TrashService(context: context, media: media).softDelete(job)
        default:
            throw FixtureError.unknownFixture
        }
    }

    private static func makeCaptureFixture(in context: ModelContext, media: MediaStore) throws -> JobRecord {
        let job = try makeJob(vehicle: "Silver Sedan Walkaround", customer: "Alex Morgan", in: context)
        let jobs = JobRepository(context: context)
        try jobs.advance(job)
        try CaptureRepository(context: context, media: media).addPhoto(
            to: job,
            data: try imageData(for: "front"),
            slotID: "front",
            phase: .before
        )
        return job
    }

    private static func makeReviewReadyJob(
        vehicle: String,
        customer: String,
        in context: ModelContext,
        media: MediaStore
    ) throws -> JobRecord {
        let job = try makeJob(vehicle: vehicle, customer: customer, in: context)
        let jobs = JobRepository(context: context)
        let capture = CaptureRepository(context: context, media: media)

        try jobs.advance(job)
        try addRequiredImages(to: job, phase: .before, capture: capture)
        try capture.addPhoto(
            to: job,
            data: try imageData(for: "scratch-closeup"),
            slotID: "front",
            phase: .before
        )
        let beforePhoto = try capture.document(for: job).photos.last {
            $0.phase == .before && $0.slotID == "front"
        }
        if let beforePhoto {
            try capture.saveFinding(
                on: job,
                finding: VehicleFinding(
                    slotID: beforePhoto.slotID,
                    kind: FindingKind.scratch.rawValue,
                    severity: FindingSeverity.minor.rawValue,
                    notes: "Small scuff on the front bumper",
                    photoIDs: [beforePhoto.id]
                )
            )
        }
        try jobs.advance(job)
        try AcknowledgmentRepository(context: context).sign(
            job: job,
            name: customer,
            strokes: [SignatureStroke(points: [
                SignaturePoint(x: 0.10, y: 0.20),
                SignaturePoint(x: 0.45, y: 0.75),
                SignaturePoint(x: 0.85, y: 0.35)
            ])]
        )
        try jobs.advance(job)
        try jobs.advance(job)
        try addRequiredImages(to: job, phase: .after, capture: capture)
        try jobs.advance(job)
        return job
    }

    private static func makeJob(vehicle: String, customer: String, in context: ModelContext) throws -> JobRecord {
        try JobRepository(context: context).createJob(
            customerName: customer,
            vehicleLabel: vehicle,
            plate: "SAMPLE",
            color: "Silver",
            serviceName: "Full detail",
            notes: "Before-service walkaround and full detail."
        )
    }

    private static func addRequiredImages(
        to job: JobRecord,
        phase: CapturePhase,
        capture: CaptureRepository
    ) throws {
        for slot in CaptureSlot.standard where slot.isRequired {
            try capture.addPhoto(to: job, data: imageData(for: slot.id), slotID: slot.id, phase: phase)
        }
    }

    private static func imageData(for slotID: String) throws -> Data {
        let photos = [
            "front": "ScreenshotFront",
            "rear": "ScreenshotRear",
            "driver-side": "ScreenshotSide",
            "passenger-side": "ScreenshotPassengerSide",
            "front-bumper": "ScreenshotFront",
            "rear-bumper": "ScreenshotRear",
            "hood-windshield": "ScreenshotFront",
            "wheels-tires": "ScreenshotWheel",
            "front-seats": "ScreenshotInterior",
            "rear-seats": "ScreenshotRearSeats",
            "dashboard-console": "ScreenshotInterior",
            "trunk": "ScreenshotCargo",
            "scratch-closeup": "ScreenshotScratchCloseup"
        ]
        guard let name = photos[slotID],
              let image = UIImage(named: name),
              let data = image.jpegData(compressionQuality: 0.85) else {
            throw FixtureError.missingPhoto(slotID)
        }
        return data
    }
}
#endif
