import SwiftData
import UIKit
import XCTest
@testable import DetailHandoff

final class EvidenceImportTests: XCTestCase {
    // Catches a suspended Photos import writing through an obsolete context after its view is gone.
    @MainActor
    func testCancelledLoadNeverMutatesRepositoryButActiveLoadSaves() async throws {
        for mode in ["cancelled", "restored", "active"] {
            let cancelled = mode != "active"
            let container = try ModelContainer(for: BusinessProfile.self, JobRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let context = container.mainContext
            context.autosaveEnabled = false
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let media = MediaStore(root: root)
            let job = JobRecord(customerName: "Test", vehicleLabel: "Car", plate: "", color: "", serviceName: "Wash", notes: "")
            context.insert(job)
            try context.save()
            let bytes = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).jpegData(withCompressionQuality: 0.9) { renderer in
                UIColor.blue.setFill()
                renderer.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
            }
            var continuation: CheckedContinuation<Data?, Never>?
            let task = Task { @MainActor in
                try await EvidenceImport.loadAndSave(load: {
                    await withCheckedContinuation { continuation = $0 }
                }, save: { data in
                    try CaptureRepository(context: context, media: media).addPhoto(to: job, data: data, slotID: "front", phase: .before)
                })
            }
            while continuation == nil { await Task.yield() }
            if mode == "cancelled" { task.cancel() }
            if mode == "restored" { EvidenceImport.invalidatePendingLoads() }
            continuation?.resume(returning: bytes)
            do {
                try await task.value
                XCTAssertFalse(cancelled)
            } catch {
                XCTAssertTrue(cancelled)
                XCTAssertTrue(error is CancellationError)
            }
            let saved = try XCTUnwrap(try ModelContext(container).fetch(FetchDescriptor<JobRecord>()).first)
            let capture = try CaptureRepository(context: context, media: media).document(for: saved)
            XCTAssertEqual(capture.photos.count, cancelled ? 0 : 1)
            if cancelled {
                XCTAssertNil(saved.captureData)
                XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
            }
        }
    }
}
