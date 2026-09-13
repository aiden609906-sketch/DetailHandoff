import CryptoKit
import Foundation

enum BackupError: LocalizedError {
    case invalidPackage(String)
    case unsavedChanges
    case cleanupFailed(any Error, any Error)

    var errorDescription: String? {
        switch self {
        case .invalidPackage(let detail): "The backup could not be verified: \(detail). No records were replaced."
        case .unsavedChanges: "Save or retry your pending changes before restoring a backup."
        case .cleanupFailed: "The restore failed and records were not replaced. Temporary imported files could not be fully removed."
        }
    }
}

/// Strict package paths have one spelling; no Windows aliases, traversal or symlink wrappers.
enum BackupPackage {
    static func validatePath(_ path: String) throws {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty, !path.contains("\\"), !path.contains(":"), !path.contains("\0"),
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw BackupError.invalidPackage("unsafe asset path")
        }
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func unpack(_ package: FileWrapper) throws -> (BackupManifest, [String: Data]) {
        guard package.isDirectory, let children = package.fileWrappers,
              Set(children.keys) == ["manifest.json", "assets"],
              let manifestBytes = children["manifest.json"]?.regularFileContents,
              children["manifest.json"]?.isRegularFile == true,
              let assets = children["assets"], assets.isDirectory else {
            throw BackupError.invalidPackage("expected a manifest and assets folder")
        }
        let manifest = try JSONDecoder().decode(BackupManifest.self, from: manifestBytes)
        guard manifest.schemaVersion == 1 else { throw BackupError.invalidPackage("unsupported schema version") }
        var files: [String: Data] = [:]
        try flatten(assets, prefix: "", into: &files)
        try validateAssets(manifest.assets, files: files)
        return (manifest, files)
    }

    /// Reused after staging: decodable media is not necessarily the original evidence bytes.
    static func validateAssets(_ assets: [BackupAsset], files: [String: Data]) throws {
        var paths = Set<String>()
        for asset in assets {
            try validatePath(asset.relativePath)
            guard paths.insert(asset.relativePath).inserted,
                  let bytes = files[asset.relativePath], asset.byteCount == bytes.count,
                  asset.sha256 == digest(bytes) else {
                throw BackupError.invalidPackage("duplicate, missing or damaged asset")
            }
        }
        guard paths == Set(files.keys) else { throw BackupError.invalidPackage("unlisted assets") }
    }

    static func make(manifest: BackupManifest, files: [String: Data]) throws -> FileWrapper {
        let assets = FileWrapper(directoryWithFileWrappers: [:])
        for (path, bytes) in files {
            try validatePath(path)
            let components = path.split(separator: "/").map(String.init)
            var folder = assets
            for component in components.dropLast() {
                if let existing = folder.fileWrappers?[component] {
                    guard existing.isDirectory else { throw BackupError.invalidPackage("conflicting asset paths") }
                    folder = existing
                } else {
                    let child = FileWrapper(directoryWithFileWrappers: [:])
                    child.preferredFilename = component
                    folder.addFileWrapper(child)
                    folder = child
                }
            }
            guard let filename = components.last, folder.fileWrappers?[filename] == nil else {
                throw BackupError.invalidPackage("conflicting asset paths")
            }
            folder.addRegularFile(withContents: bytes, preferredFilename: filename)
        }
        return FileWrapper(directoryWithFileWrappers: [
            "manifest.json": FileWrapper(regularFileWithContents: try JSONEncoder().encode(manifest)),
            "assets": assets
        ])
    }

    private static func flatten(_ folder: FileWrapper, prefix: String, into files: inout [String: Data]) throws {
        guard folder.isDirectory, let children = folder.fileWrappers else {
            throw BackupError.invalidPackage("invalid asset folder")
        }
        guard prefix.isEmpty || !children.isEmpty else { throw BackupError.invalidPackage("unlisted empty folder") }
        for (name, child) in children {
            guard !name.contains("/") else { throw BackupError.invalidPackage("invalid filename") }
            let path = prefix.isEmpty ? name : "\(prefix)/\(name)"
            try validatePath(path)
            if child.isDirectory { try flatten(child, prefix: path, into: &files) }
            else if child.isRegularFile, let bytes = child.regularFileContents {
                guard files.updateValue(bytes, forKey: path) == nil else { throw BackupError.invalidPackage("duplicate path") }
            } else { throw BackupError.invalidPackage("symbolic links and special files are not allowed") }
        }
    }
}
