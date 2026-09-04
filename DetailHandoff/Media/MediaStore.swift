import Foundation
import UIKit

enum MediaStoreError: Error, Equatable {
    case invalidImage
    case unsafeRelativePath(String)
    case jpegEncodingFailed
}

struct StoredImage: Equatable {
    var imagePath: String
    var thumbnailPath: String

    init(imagePath: String, thumbnailPath: String) {
        self.imagePath = imagePath
        self.thumbnailPath = thumbnailPath
    }
}

final class MediaStore {
    static var defaultRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DetailHandoff", isDirectory: true)
            .appendingPathComponent("CaptureMedia", isDirectory: true)
    }

    private let root: URL
    private let fileManager: FileManager

    init(root: URL) {
        self.root = root.standardizedFileURL
        self.fileManager = .default
    }

    func storeImage(_ data: Data, jobID: UUID) throws -> StoredImage {
        guard let image = UIImage(data: data) else { throw MediaStoreError.invalidImage }
        let imageData = try jpegData(for: image, maximumDimension: 2048)
        let thumbnailData = try jpegData(for: image, maximumDimension: 480)
        let directory = jobID.uuidString
        let filename = UUID().uuidString
        let stored = StoredImage(
            imagePath: "\(directory)/\(filename).jpg",
            thumbnailPath: "\(directory)/\(filename)-thumb.jpg"
        )
        let imageURL = try url(for: stored.imagePath)
        let thumbnailURL = try url(for: stored.thumbnailPath)
        try fileManager.createDirectory(at: imageURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        do {
            try imageData.write(to: imageURL, options: .atomic)
            try thumbnailData.write(to: thumbnailURL, options: .atomic)
        } catch {
            removeFileIfPresent(at: imageURL)
            removeFileIfPresent(at: thumbnailURL)
            throw error
        }
        return stored
    }

    func url(for relativePath: String) throws -> URL {
        guard isSafeRelativePath(relativePath) else { throw MediaStoreError.unsafeRelativePath(relativePath) }
        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let candidate = resolvedRoot.appendingPathComponent(relativePath).standardizedFileURL.resolvingSymlinksInPath()
        guard candidate.path.hasPrefix(resolvedRoot.path + "/") else {
            throw MediaStoreError.unsafeRelativePath(relativePath)
        }
        return candidate
    }

    func remove(_ image: StoredImage) throws {
        let imageURL = try url(for: image.imagePath)
        let thumbnailURL = try url(for: image.thumbnailPath)
        if fileManager.fileExists(atPath: imageURL.path) { try fileManager.removeItem(at: imageURL) }
        if fileManager.fileExists(atPath: thumbnailURL.path) { try fileManager.removeItem(at: thumbnailURL) }
        try removeEmptyParentDirectories(startingAt: imageURL.deletingLastPathComponent())
    }

    private func jpegData(for image: UIImage, maximumDimension: CGFloat) throws -> Data {
        guard image.size.width > 0, image.size.height > 0 else { throw MediaStoreError.invalidImage }
        let scale = min(1, maximumDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = rendered.jpegData(compressionQuality: 0.9) else { throw MediaStoreError.jpegEncodingFailed }
        return data
    }

    private func isSafeRelativePath(_ relativePath: String) -> Bool {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty, !normalized.hasPrefix("/"), !normalized.hasPrefix("\\"), !normalized.contains(":") else {
            return false
        }
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        return !components.isEmpty && components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private func removeFileIfPresent(at url: URL) {
        if fileManager.fileExists(atPath: url.path) { try? fileManager.removeItem(at: url) }
    }

    private func removeEmptyParentDirectories(startingAt directory: URL) throws {
        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        var current = directory.resolvingSymlinksInPath().standardizedFileURL
        while current.path.hasPrefix(resolvedRoot.path + "/") {
            guard try fileManager.contentsOfDirectory(atPath: current.path).isEmpty else { return }
            try fileManager.removeItem(at: current)
            current = current.deletingLastPathComponent()
        }
        if current == resolvedRoot, fileManager.fileExists(atPath: current.path), try fileManager.contentsOfDirectory(atPath: current.path).isEmpty {
            try fileManager.removeItem(at: current)
        }
    }
}
