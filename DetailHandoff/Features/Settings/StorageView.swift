import SwiftData
import SwiftUI

struct StorageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var summary: StorageSummary?
    @State private var errorMessage: String?
    @State private var confirmingCleanup = false
    @State private var completionMessage: String?

    var body: some View {
        Form {
            Section("Protect your records") {
                Text("Export a backup before cleanup. Permanent deletion and unreferenced-file cleanup cannot be undone on this device.")
                NavigationLink("Backup and restore") { BackupView() }
                NavigationLink("Recently deleted") { RecentlyDeletedView() }
            }
            Section("On-device media") {
                if let summary {
                    LabeledContent("Total used", value: bytes(summary.totalBytes))
                    LabeledContent("Unreferenced files", value: bytes(summary.reclaimableBytes))
                    Text("Includes originals, thumbnails, logos, report PDFs and files retained after photo removal or backup restore. The records database is not included.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Clean unreferenced files", role: .destructive) { confirmingCleanup = true }
                        .disabled(summary.reclaimableBytes == 0)
                } else {
                    Text("Storage usage is unavailable until all saved references can be read safely.")
                        .foregroundStyle(.secondary)
                }
                Button("Refresh storage", action: refresh)
            }
            if let summary {
                Section("Storage by job") {
                    if summary.jobs.isEmpty { Text("No saved jobs") }
                    ForEach(summary.jobs) { job in
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent(job.title, value: bytes(job.bytes))
                            Text(job.customer.isEmpty ? "Customer not provided" : job.customer)
                                .font(.caption).foregroundStyle(.secondary)
                            if job.isDeleted { Text("Recently deleted").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    Text("Per-job usage includes retained files in that job’s folder. Shared evidence may appear under more than one job; total usage counts each file once.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Storage")
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        .confirmationDialog("Permanently remove unreferenced files?", isPresented: $confirmingCleanup, titleVisibility: .visible) {
            Button("Remove unreferenced files", role: .destructive, action: clean)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(bytes(summary?.reclaimableBytes ?? 0)) of files that are not referenced by any job, retained deleted job, frozen report, or current logo. Removed photos and old restore files cannot be recovered afterward. Backups protect saved records and referenced evidence, but do not include these unreferenced files.")
        }
        .alert("Storage needs attention", isPresented: errorShown) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .alert("Cleanup complete", isPresented: completionShown) {
            Button("OK", role: .cancel) {}
        } message: { Text(completionMessage ?? "") }
    }

    private var service: TrashService { TrashService(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot)) }
    private var errorShown: Binding<Bool> { Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }) }
    private var completionShown: Binding<Bool> { Binding(get: { completionMessage != nil }, set: { if !$0 { completionMessage = nil } }) }
    private func bytes(_ count: Int64) -> String { ByteCountFormatter.string(fromByteCount: count, countStyle: .file) }

    private func refresh() {
        do { summary = try service.storageSummary() }
        catch { summary = nil; errorMessage = error.localizedDescription }
    }

    private func clean() {
        do {
            try service.cleanOrphans()
            summary = try service.storageSummary()
            completionMessage = "Unreferenced files were removed. All currently referenced evidence was retained."
        } catch {
            errorMessage = error.localizedDescription
            summary = try? service.storageSummary()
        }
    }
}
