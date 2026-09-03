import SwiftData
import SwiftUI

enum JobsListContentState: Equatable {
    case firstJob
    case noSearchResults
    case jobs

    static func classify(activeJobCount: Int, visibleJobCount: Int) -> JobsListContentState {
        guard activeJobCount > 0 else {
            return .firstJob
        }

        return visibleJobCount > 0 ? .jobs : .noSearchResults
    }
}

struct JobsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JobRecord.createdAt, order: .reverse) private var jobs: [JobRecord]

    @State private var searchText = ""
    @State private var isShowingNewJob = false

    private var activeJobs: [JobRecord] {
        jobs.filter { $0.deletedAt == nil }
    }

    private var visibleJobs: [JobRecord] {
        JobRepository(context: modelContext).search(
            activeJobs,
            query: searchText
        )
    }

    private var contentState: JobsListContentState {
        JobsListContentState.classify(
            activeJobCount: activeJobs.count,
            visibleJobCount: visibleJobs.count
        )
    }

    var body: some View {
        NavigationStack {
            List {
                switch contentState {
                case .firstJob:
                    ContentUnavailableView(
                        "No jobs yet",
                        systemImage: "car",
                        description: Text("Create a job to start your first report.")
                    )
                case .noSearchResults:
                    ContentUnavailableView(
                        "No matching jobs",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different customer, vehicle, or plate.")
                    )
                case .jobs:
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
