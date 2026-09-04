import SwiftData
import SwiftUI

struct RecentlyDeletedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<JobRecord> { $0.deletedAt != nil }, sort: \JobRecord.deletedAt, order: .reverse) private var jobs: [JobRecord]
    @State private var pendingDeletion: JobRecord?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Text("Deleted jobs can be restored for 30 days. After exactly 30 days, they expire and are permanently removed when the app next checks retention. Backups include retained deleted jobs.")
                NavigationLink("Back up before deleting") { BackupView() }
            }
            Section("Deleted jobs") {
                if jobs.isEmpty {
                    ContentUnavailableView("No recently deleted jobs", systemImage: "trash", description: Text("Jobs moved here stay recoverable for 30 days."))
                }
                ForEach(jobs) { job in
                    TimelineView(.periodic(from: .now, by: 30)) { timeline in
                        let expiry = job.deletedAt.map(TrashService.expiresAt)
                        let expired = expiry.map { timeline.date >= $0 } ?? true
                        VStack(alignment: .leading, spacing: 8) {
                            Text(job.vehicleLabel).font(.headline)
                            Text("\(job.customerName.isEmpty ? "Customer not provided" : job.customerName) · \(job.plate)")
                                .font(.subheadline).foregroundStyle(.secondary)
                            if let expiry {
                                Text(expired ? "Expired — no longer recoverable" : "Recoverable until \(expiry.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            HStack {
                                Button("Restore") { restore(job) }.disabled(expired)
                                Spacer()
                                Button("Delete permanently", role: .destructive) { pendingDeletion = job }
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Recently deleted")
        .confirmationDialog("Permanently delete this job?", isPresented: confirmationShown, titleVisibility: .visible, presenting: pendingDeletion) { job in
            Button("Delete permanently", role: .destructive) { permanentlyDelete(job) }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { job in
            Text("\(job.vehicleLabel) · \(job.plate) · \(job.customerName.isEmpty ? "Customer not provided" : job.customerName)\n\nThis permanently deletes the job and its unshared evidence files, including report versions. It cannot be undone. Export a backup first.")
        }
        .alert("Recently deleted needs attention", isPresented: errorShown) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private var service: TrashService { TrashService(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot)) }
    private var confirmationShown: Binding<Bool> { Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }) }
    private var errorShown: Binding<Bool> { Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }) }
    private func restore(_ job: JobRecord) {
        do { try service.restore(job) }
        catch { errorMessage = error.localizedDescription }
    }
    private func permanentlyDelete(_ job: JobRecord) {
        pendingDeletion = nil
        do { try service.permanentlyDelete(job) }
        catch { errorMessage = error.localizedDescription }
    }
}
