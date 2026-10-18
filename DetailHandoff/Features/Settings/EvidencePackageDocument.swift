import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let detailHandoffBackup = UTType(exportedAs: "com.aiden609906.detailhandoff.backup", conformingTo: .package)
}

struct EvidencePackageDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.detailHandoffBackup] }
    let package: FileWrapper

    init(package: FileWrapper) { self.package = package }
    init(configuration: ReadConfiguration) throws { package = configuration.file }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { package }
}

struct ZipExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

enum EvidenceFileResult {
    static func isCancellation(_ error: any Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
    }
}
