import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let detailHandoffBackup = UTType(exportedAs: "com.aiden609906.detailhandoff.backup", conformingTo: .package)
    static let detailHandoffPhotos = UTType(exportedAs: "com.aiden609906.detailhandoff.photos", conformingTo: .package)
}

struct EvidencePackageDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.detailHandoffBackup, .detailHandoffPhotos] }
    let package: FileWrapper

    init(package: FileWrapper) { self.package = package }
    init(configuration: ReadConfiguration) throws { package = configuration.file }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { package }
}

enum EvidenceFileResult {
    static func isCancellation(_ error: any Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
    }
}
