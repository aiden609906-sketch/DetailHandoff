#if DEBUG
import Foundation
import SwiftData
import UIKit

@MainActor
enum UITestFixtures {
    private enum FixtureError: Error { case unknownFixture }
    private static let testArgument = "--ui-testing"
    private static let fixtureArgument = "--screenshot-fixture"
    private static let startupFailureArgument = "--startup-failure"
    private static var didPrepareStore = false
    private static var didFailStartup = false

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(testArgument)
    }

    static var mediaRoot: URL? {
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
            try prepareStore()
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

    private static var root: URL {
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
            businessName: "Fixture Detail",
            phone: "555-0100",
            email: "fixtures@example.test",
            configuration: .standard
        )

        switch requestedFixture {
        case "complete":
            _ = try makeReviewReadyJob(
                vehicle: "Complete Fixture Sedan",
                customer: "Taylor Fixture",
                in: context,
                media: media
            )
            try makeCaptureFixture(in: context, media: media)
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

    private static func makeCaptureFixture(in context: ModelContext, media: MediaStore) throws {
        let job = try makeJob(vehicle: "Capture Fixture Coupe", customer: "Casey Fixture", in: context)
        let jobs = JobRepository(context: context)
        try jobs.advance(job)
        try CaptureRepository(context: context, media: media).addPhoto(
            to: job,
            data: imageData(index: 0),
            slotID: "front",
            phase: .before
        )
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
        let beforePhoto = try capture.document(for: job).photos.first { $0.phase == .before }
        if let beforePhoto {
            try capture.saveFinding(
                on: job,
                finding: VehicleFinding(
                    slotID: beforePhoto.slotID,
                    kind: FindingKind.scratch.rawValue,
                    severity: FindingSeverity.minor.rawValue,
                    notes: "Fixture door-edge mark",
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
            plate: "FIX-017",
            color: "Silver",
            serviceName: "Full detail",
            notes: "Generated only for DEBUG UI verification."
        )
    }

    private static func addRequiredImages(
        to job: JobRecord,
        phase: CapturePhase,
        capture: CaptureRepository
    ) throws {
        for (index, slot) in CaptureSlot.standard.enumerated() where slot.isRequired {
            try capture.addPhoto(to: job, data: imageData(index: index), slotID: slot.id, phase: phase)
        }
    }

    private static func imageData(index: Int) -> Data {
        let size = CGSize(width: index.isMultiple(of: 2) ? 480 : 240, height: index.isMultiple(of: 2) ? 240 : 480)
        return UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.85) { context in
            UIColor(hue: CGFloat(index) / 12, saturation: 0.45, brightness: 0.85, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            ("Fixture evidence \(index + 1)" as NSString).draw(
                at: CGPoint(x: 20, y: 40),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 20), .foregroundColor: UIColor.black]
            )
        }
    }
}
#endif
