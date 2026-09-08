import SwiftData
import UIKit
import XCTest
@testable import DetailHandoff

final class FinalReviewResourceTests: XCTestCase {
    // Without preparing the directory, the first capacity lookup fails after no-logo onboarding.
    @MainActor
    func testFirstCapacityCheckAfterOnboardingWithoutLogoUsesExistingEmptyMediaDirectory() throws {
        let container = try makeContainer()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = directory.appendingPathComponent("CaptureMedia", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let profile = try BusinessRepository(context: container.mainContext, media: MediaStore(root: root))
            .createProfile(businessName: "Clean install", phone: "", email: "", configuration: .standard)
        XCTAssertNil(profile.logoImagePath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))

        // Only the OS capacity value is substituted; directory creation and lookup are real.
        let checker = FileSystemCaptureStorageCapacityChecker(root: root, readCapacity: { url in
            XCTAssertEqual(url.standardizedFileURL, root.standardizedFileURL)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: url.path), [])
            return 500 * 1_024 * 1_024
        })
        XCTAssertEqual(CapturePresentationState.storageDecision(availableBytes: try checker.availableImportantCapacity()), .ready)
        XCTAssertEqual(try MediaStore(root: root).assetInventory(), [])
    }

    // An unknown/failed OS query or an unusable destination must never become permission to capture.
    func testCapacityCheckerFailsClosedForNilErrorAndNonDirectoryDestination() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try FileSystemCaptureStorageCapacityChecker(root: root, readCapacity: { _ in nil }).availableImportantCapacity())
        XCTAssertThrowsError(try FileSystemCaptureStorageCapacityChecker(root: root, readCapacity: { _ in throw CocoaError(.fileReadUnknown) }).availableImportantCapacity())
        let file = root.appendingPathComponent("file")
        try Data([1]).write(to: file)
        XCTAssertThrowsError(try FileSystemCaptureStorageCapacityChecker(root: file, readCapacity: { _ in
            XCTFail("A file cannot be used as the capture directory")
            return 500 * 1_024 * 1_024
        }).availableImportantCapacity())
    }

    // A zero-frame overlay makes its reference invisible; rotation must resize the actual UIView.
    @MainActor
    func testCameraReferenceOverlayResizesAndKeepsSystemControlAreasClear() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300)).image { _ in }
        let overlay = CameraReferenceOverlayView(image: image)
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        overlay.updateLayout(in: host.bounds, safeAreaInsets: UIEdgeInsets(top: 47, left: 0, bottom: 34, right: 0))
        host.addSubview(overlay)
        overlay.layoutIfNeeded()
        XCTAssertEqual(overlay.frame, host.bounds)
        XCTAssertGreaterThan(overlay.imageView.frame.width, 0)
        XCTAssertGreaterThan(overlay.imageView.frame.height, 0)
        XCTAssertGreaterThanOrEqual(overlay.imageView.frame.minY, 72)
        XCTAssertLessThanOrEqual(overlay.imageView.frame.maxY, host.bounds.height - 160)
        XCTAssertNil(overlay.hitTest(CGPoint(x: 195, y: 780), with: nil))

        host.frame.size = CGSize(width: 844, height: 390)
        XCTAssertEqual(overlay.frame, host.bounds, "The overlay must follow its host before SwiftUI sends an update.")
        overlay.updateLayout(in: host.bounds, safeAreaInsets: UIEdgeInsets(top: 0, left: 47, bottom: 21, right: 47))
        overlay.layoutIfNeeded()
        XCTAssertEqual(overlay.frame, host.bounds)
        XCTAssertGreaterThan(overlay.imageView.frame.height, 0)
        XCTAssertGreaterThanOrEqual(overlay.imageView.frame.minX, 71)
        XCTAssertLessThanOrEqual(overlay.imageView.frame.maxX, 773)
        XCTAssertLessThanOrEqual(overlay.imageView.frame.maxY, 230)
        XCTAssertFalse(overlay.isUserInteractionEnabled)
        XCTAssertTrue(overlay.autoresizingMask.contains(.flexibleWidth))
        XCTAssertTrue(overlay.autoresizingMask.contains(.flexibleHeight))
    }

    // Missing resource membership or an incorrect reason must fail against the built app bundle.
    func testBundledPrivacyManifestDeclaresDiskSpacePurposeWithoutTrackingOrCollection() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try XCTUnwrap(try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual(plist["NSPrivacyTrackingDomains"] as? [String], [])
        XCTAssertEqual((plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]])?.count, 0)
        let apiTypes = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let disk = try XCTUnwrap(apiTypes.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryDiskSpace" })
        XCTAssertEqual(disk["NSPrivacyAccessedAPITypeReasons"] as? [String], ["E174.1"])
    }
}
