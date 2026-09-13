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

struct MediaAsset: Equatable {
    let path: String
    let bytes: Int64
}

final class MediaStore {
    static var defaultRoot: URL {
        #if DEBUG
        if let root = UITestFixtures.mediaRoot {
            return root
        }
        #endif
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
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
        let imageData = try jpegData(for: image, maximumDimension: 2560)
        let thumbnailData = try jpegData(for: image, maximumDimension: 320)
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

    /// Business logos remain private application-support assets and are compressed before storage.
    func storeBusinessLogo(_ data: Data) throws -> String {
        guard let image = UIImage(data: data) else { throw MediaStoreError.invalidImage }
        let compressed = try jpegData(for: image, maximumDimension: 1024)
        let path = "Branding/\(UUID().uuidString).jpg"
        let destination = try url(for: path)
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try compressed.write(to: destination, options: .atomic)
        return path
    }

    func url(for relativePath: String) throws -> URL {
        guard let components = safeRelativePathComponents(relativePath) else {
            throw MediaStoreError.unsafeRelativePath(relativePath)
        }
        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        var candidate = resolvedRoot
        for component in components {
            candidate = candidate.appendingPathComponent(component).resolvingSymlinksInPath().standardizedFileURL
            guard candidate.path.hasPrefix(resolvedRoot.path + "/") else {
                throw MediaStoreError.unsafeRelativePath(relativePath)
            }
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

    func removeAsset(at relativePath: String) throws {
        let assetURL = try url(for: relativePath)
        if fileManager.fileExists(atPath: assetURL.path) {
            try fileManager.removeItem(at: assetURL)
        }
    }

    /// Backup never follows a symbolic link, even if its target happens to remain in the root.
    func readRegularAsset(at relativePath: String) throws -> Data {
        try validatePrivateRoot()
        try BackupPackage.validatePath(relativePath)
        var candidate = root
        for component in relativePath.split(separator: "/") {
            candidate.appendPathComponent(String(component))
            let values = try candidate.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw MediaStoreError.unsafeRelativePath(relativePath) }
        }
        guard try candidate.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw MediaStoreError.unsafeRelativePath(relativePath)
        }
        return try Data(contentsOf: url(for: relativePath))
    }

    /// Enumerates even unlinked capture files and media retained by a previous restore.
    /// Refuse unsafe entries instead of following them or reporting an incomplete inventory.
    func assetInventory() throws -> [MediaAsset] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        try validatePrivateRoot()
        var assets: [MediaAsset] = []
        func visit(_ directory: URL, prefix: String) throws {
            for entry in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey, .fileSizeKey]) {
                let path = prefix + entry.lastPathComponent
                try BackupPackage.validatePath(path)
                let values = try entry.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey, .fileSizeKey])
                guard values.isSymbolicLink != true else { throw MediaStoreError.unsafeRelativePath(path) }
                if values.isDirectory == true {
                    try visit(entry, prefix: path + "/")
                } else {
                    guard values.isRegularFile == true, let bytes = values.fileSize else {
                        throw MediaStoreError.unsafeRelativePath(path)
                    }
                    assets.append(MediaAsset(path: path, bytes: Int64(bytes)))
                }
            }
        }
        try visit(root, prefix: "")
        return assets.sorted { $0.path < $1.path }
    }

    /// Cleanup may only unlink a regular file whose complete path was checked without symlinks.
    func removeRegularAsset(at relativePath: String) throws {
        _ = try readRegularAsset(at: relativePath)
        try fileManager.removeItem(at: url(for: relativePath))
    }

    private func validatePrivateRoot() throws {
        guard try root.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
            throw MediaStoreError.unsafeRelativePath(root.path)
        }
    }

    private func jpegData(for image: UIImage, maximumDimension: CGFloat) throws -> Data {
        guard image.size.width > 0, image.size.height > 0 else { throw MediaStoreError.invalidImage }
        let sourceWidth = image.cgImage?.width ?? Int((image.size.width * image.scale).rounded(.down))
        let sourceHeight = image.cgImage?.height ?? Int((image.size.height * image.scale).rounded(.down))
        guard sourceWidth > 0, sourceHeight > 0 else { throw MediaStoreError.invalidImage }
        let longestSide = max(sourceWidth, sourceHeight)
        let targetLongestSide = min(Int(maximumDimension), longestSide)
        let targetWidth = max(1, Int((Double(sourceWidth) * Double(targetLongestSide) / Double(longestSide)).rounded(.down)))
        let targetHeight = max(1, Int((Double(sourceHeight) * Double(targetLongestSide) / Double(longestSide)).rounded(.down)))
        let size = CGSize(width: CGFloat(targetWidth), height: CGFloat(targetHeight))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = rendered.jpegData(compressionQuality: 0.9) else { throw MediaStoreError.jpegEncodingFailed }
        return data
    }

    private func safeRelativePathComponents(_ relativePath: String) -> [String]? {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty, !normalized.hasPrefix("/"), !normalized.hasPrefix("\\"), !normalized.contains(":") else {
            return nil
        }
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty, components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            return nil
        }
        return components.map(String.init)
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
