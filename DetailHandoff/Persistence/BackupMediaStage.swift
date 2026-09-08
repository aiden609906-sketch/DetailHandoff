import Darwin
import Foundation

/// The operation owns exactly this newly claimed directory, never preexisting application files.
final class BackupMediaStage {
    let namespace: String
    private let directory: URL
    private let media: MediaStore

    init(media: MediaStore) throws {
        self.media = media
        namespace = "Restores/\(UUID().uuidString)"
        directory = try media.url(for: namespace)
        try FileManager.default.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard mkdir(directory.path, mode_t(S_IRWXU)) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }

    func write(_ files: [String: Data], pdfPaths: Set<String>) throws -> [String: String] {
        var paths: [String: String] = [:]
        // Flat generated names avoid case/Unicode aliases and file/directory conflicts from imports.
        for (index, original) in files.keys.sorted().enumerated() {
            // The graph has already validated report ownership, PDF content and checksum.
            // Never carry an imported filename extension into the private destination.
            let suffix = pdfPaths.contains(original) ? "pdf" : "asset"
            let path = "\(namespace)/\(index).\(suffix)"
            guard let bytes = files[original] else { throw BackupError.invalidPackage("missing staged bytes") }
            try bytes.write(to: media.url(for: path), options: .atomic)
            paths[original] = path
        }
        return paths
    }

    func discard() throws {
        try FileManager.default.removeItem(at: directory)
    }
}
