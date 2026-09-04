import UIKit
import XCTest
@testable import DetailHandoff

final class MediaStoreTests: XCTestCase {
    private var root: URL!

    override func setUp() { super.setUp(); root = makeTemporaryRoot() }
    override func tearDown() { try? FileManager.default.removeItem(at: root); super.tearDown() }

    func testURLRejectsTraversalAndAbsolutePaths() throws {
        let store = MediaStore(root: root)
        XCTAssertThrowsError(try store.url(for: "../outside.jpg"))
        XCTAssertThrowsError(try store.url(for: "/outside.jpg"))
        XCTAssertThrowsError(try store.url(for: "C:\\outside.jpg"))
    }

    func testURLRejectsSymlinkThatEscapesPrivateRoot() throws {
        let outside = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("escape"), withDestinationURL: outside)
        XCTAssertThrowsError(try MediaStore(root: root).url(for: "escape/photo.jpg"))
    }

    func testStoreImageWritesResizedJPEGAndThumbnailUnderJobDirectory() throws {
        let store = MediaStore(root: root)
        let stored = try store.storeImage(try XCTUnwrap(makeJPEG(width: 3000, height: 2000)), jobID: UUID())
        let fullImage = try XCTUnwrap(UIImage(data: Data(contentsOf: try store.url(for: stored.imagePath))))
        let thumbnail = try XCTUnwrap(UIImage(data: Data(contentsOf: try store.url(for: stored.thumbnailPath))))
        XCTAssertFalse(stored.imagePath.hasPrefix("/"))
        XCTAssertFalse(stored.thumbnailPath.hasPrefix("/"))
        XCTAssertLessThanOrEqual(max(fullImage.size.width, fullImage.size.height), 2048)
        XCTAssertLessThanOrEqual(max(thumbnail.size.width, thumbnail.size.height), 480)
    }

    func testInvalidImageDoesNotCreateEvidenceFiles() throws {
        XCTAssertThrowsError(try MediaStore(root: root).storeImage(Data([0x01, 0x02]), jobID: UUID()))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    private func makeJPEG(width: CGFloat, height: CGFloat) -> Data? {
        UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).jpegData(withCompressionQuality: 0.9) { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
