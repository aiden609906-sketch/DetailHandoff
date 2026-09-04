import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(\.modelContext) private var modelContext
    var canExport = true
    @State private var document: EvidencePackageDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingRestore: ValidatedBackup?
    @State private var confirmingRestore = false
    @State private var resultMessage: String?

    var body: some View {
        Form {
            Section("Local backup") {
                Text("A backup includes business settings, every job (including deleted jobs), photos, signatures and sealed reports. Keep a copy outside this device before deleting the app or changing phones.")
                if canExport {
                    Button("Export backup to Files", systemImage: "square.and.arrow.up", action: exportBackup)
                        .accessibilityIdentifier("backup.export")
                }
                Button("Restore backup from Files", systemImage: "square.and.arrow.down") { importing = true }
                    .accessibilityIdentifier("backup.restore")
            }
            Section("Privacy") {
                Text("Backups are not encrypted by this app and contain customer information. Choose a secure destination in Files. Nothing is uploaded automatically.")
                Text("Restore replaces all jobs and settings on this device. It preserves already-issued report number reservations. Export a current backup first if you want to keep the current records.")
            }
        }
        .navigationTitle("Backup and restore")
        .fileExporter(isPresented: $exporting, document: document, contentType: .detailHandoffBackup, defaultFilename: "DetailHandoff-backup") { result in
            document = nil
            switch result {
            case .success: resultMessage = "Backup export complete. Keep the saved package in a safe place."
            case .failure(let error): if !EvidenceFileResult.isCancellation(error) { resultMessage = "Backup export failed: \(error.localizedDescription)" }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.detailHandoffBackup]) { result in
            switch result {
            case .success(let url): loadBackup(url)
            case .failure(let error): if !EvidenceFileResult.isCancellation(error) { resultMessage = "Backup could not be opened: \(error.localizedDescription)" }
            }
        }
        .confirmationDialog("Replace all jobs and settings?", isPresented: $confirmingRestore, titleVisibility: .visible) {
            Button("Replace with backup", role: .destructive, action: restore)
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            if let pendingRestore {
                Text("This verified backup contains \(pendingRestore.jobCount) jobs and was created \(pendingRestore.createdAt.formatted()). Your current jobs and settings will be replaced.")
            }
        }
        .alert("Backup and restore", isPresented: showingResult) { Button("OK", role: .cancel) {} } message: { Text(resultMessage ?? "") }
    }

    private var service: BackupService { BackupService(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot)) }
    private var showingResult: Binding<Bool> {
        Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })
    }

    private func exportBackup() {
        do {
            document = EvidencePackageDocument(package: try service.makeBackup())
            exporting = true
        } catch { resultMessage = "Backup export failed: \(error.localizedDescription)" }
    }

    private func loadBackup(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let package = try FileWrapper(url: url, options: .immediate)
            pendingRestore = try service.validate(package)
            confirmingRestore = true
        } catch {
            pendingRestore = nil
            resultMessage = "Backup validation failed: \(error.localizedDescription)"
        }
    }

    private func restore() {
        guard let pendingRestore else { return }
        do {
            try service.restore(pendingRestore)
            // RootView replaces this navigation tree and displays the success message.
        } catch { resultMessage = "Restore failed: \(error.localizedDescription)" }
        self.pendingRestore = nil
    }
}
