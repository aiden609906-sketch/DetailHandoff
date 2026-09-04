import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PhotoExportView: View {
    @Environment(\.modelContext) private var modelContext
    let job: JobRecord
    @State private var document: EvidencePackageDocument?
    @State private var exporting = false
    @State private var resultMessage: String?

    var body: some View {
        Form {
            Text("Export all current Before and After photos at their stored full resolution. The included manifest identifies each photo’s position and capture date. Frozen report evidence remains in the full backup.")
            Button("Export photos to Files", systemImage: "square.and.arrow.up") {
                do {
                    let service = BackupService(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot))
                    document = EvidencePackageDocument(package: try service.exportPhotos(for: job))
                    exporting = true
                } catch { resultMessage = "Photo export failed: \(error.localizedDescription)" }
            }
            .accessibilityIdentifier("job.exportPhotos")
        }
        .navigationTitle("Export photos")
        .fileExporter(isPresented: $exporting, document: document, contentType: .detailHandoffPhotos, defaultFilename: "DetailHandoff-photos-\(job.id.uuidString)") { result in
            document = nil
            switch result {
            case .success: resultMessage = "Photo export complete."
            case .failure(let error): if !EvidenceFileResult.isCancellation(error) { resultMessage = "Photo export failed: \(error.localizedDescription)" }
            }
        }
        .alert("Photo export", isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(resultMessage ?? "") }
    }
}
