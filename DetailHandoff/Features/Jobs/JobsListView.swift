import SwiftData
import SwiftUI

struct JobsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JobRecord.createdAt, order: .reverse) private var jobs: [JobRecord]

    @State private var searchText = ""
    @State private var isShowingNewJob = false

    private var visibleJobs: [JobRecord] {
        JobRepository(context: modelContext).search(
            jobs.filter { $0.deletedAt == nil },
            query: searchText
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if visibleJobs.isEmpty {
                    ContentUnavailableView(
                        "No jobs yet",
                        systemImage: "car",
                        description: Text("Create a job to start your first report.")
                    )
                } else {
                    ForEach(visibleJobs) { job in
                        NavigationLink {
                            JobWorkflowView(job: job)
                        } label: {
                            JobRow(job: job)
                        }
                    }
                }
            }
            .navigationTitle("Jobs")
            .searchable(text: $searchText, prompt: "Customer, vehicle, or plate")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New job", systemImage: "plus") {
                        isShowingNewJob = true
                    }
                }
            }
            .sheet(isPresented: $isShowingNewJob) {
                NewJobView()
            }
        }
    }
}

private struct JobRow: View {
    let job: JobRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(job.vehicleLabel)
                .font(.headline)

            Text(job.customerName.isEmpty ? "Customer not provided" : job.customerName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text(job.status.displayName)
                Spacer()
                Text(job.createdAt, format: .dateTime.month(.abbreviated).day().year())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
