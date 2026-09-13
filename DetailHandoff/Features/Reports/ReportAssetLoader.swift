import CryptoKit
import Foundation

enum ReportAssetLoaderError: Error, Equatable, LocalizedError {
    case unavailable
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "The saved PDF is unavailable on this device. It cannot be previewed or shared."
        case .checksumMismatch:
            "The saved PDF does not match its sealed checksum. It cannot be previewed or shared."
        }
    }
}

struct StoredReportAsset: Equatable {
    let url: URL
    let data: Data
}

/// Opens only the immutable file identified by a stored version and verifies it before display.
enum ReportAssetLoader {
    static func load(version: ReportVersion, media: MediaStore) throws -> StoredReportAsset {
        let url: URL
        do {
            url = try media.url(for: version.pdfPath)
        } catch {
            throw ReportAssetLoaderError.unavailable
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ReportAssetLoaderError.unavailable
        }

        let checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard checksum.caseInsensitiveCompare(version.sha256) == .orderedSame else {
            throw ReportAssetLoaderError.checksumMismatch
        }
        return StoredReportAsset(url: url, data: data)
    }
}
