import Foundation

/// A view-lifetime import must not write after an async picker load outlives that view.
@MainActor
enum EvidenceImport {
    private static var generation = UUID()

    static func invalidatePendingLoads() { generation = UUID() }

    static func loadAndSave(load: () async throws -> Data?, save: (Data) throws -> Void) async throws {
        try Task.checkCancellation()
        let startedIn = generation
        let bytes = try await load()
        try Task.checkCancellation()
        guard startedIn == generation else { throw CancellationError() }
        guard let bytes else { throw CocoaError(.fileReadCorruptFile) }
        try save(bytes)
    }
}
