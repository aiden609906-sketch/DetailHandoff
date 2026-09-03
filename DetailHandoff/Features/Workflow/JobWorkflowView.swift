import SwiftData
import SwiftUI

struct JobWorkflowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let job: JobRecord

    @State private var advanceErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing24) {
                jobSummary
                workflowProgress
                WorkflowStepContent(status: job.status)

                if job.status != .archived {
                    Button(action: advanceJob) {
                        Label(nextStepTitle, systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(AppTheme.spacing16)
        }
        .navigationTitle(job.vehicleLabel)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Unable to advance job", isPresented: isShowingAdvanceError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(advanceErrorMessage ?? "Please try again.")
        }
    }

    private var jobSummary: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(job.vehicleLabel)
                .font(.title2.weight(.semibold))

            LabeledContent("Customer", value: customerName)
            LabeledContent("Service", value: job.serviceName)
            LabeledContent("Current status", value: job.status.displayName)
        }
        .reportCard()
    }

    private var workflowProgress: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            Text("Workflow progress")
                .font(.headline)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: AppTheme.spacing8) {
                    ForEach(JobStatus.allCases) { status in
                        let stepState = WorkflowProgressLayout.state(
                            for: status,
                            current: job.status
                        )

                        VStack(spacing: 4) {
                            Circle()
                                .fill(progressColor(for: stepState))
                                .frame(width: 12, height: 12)

                            Text(status.displayName)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(
                            width: WorkflowProgressLayout.minimumStepWidth(
                                for: dynamicTypeSize
                            ),
                            alignment: .top
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "\(status.displayName), \(stepState.accessibilityValue)"
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.visible)
        }
    }

    private var customerName: String {
        job.customerName.isEmpty ? "Not provided" : job.customerName
    }

    private var nextStepTitle: String {
        guard let nextStatus = job.status.next else {
            return "Continue"
        }

        return "Continue to \(nextStatus.displayName)"
    }

    private var isShowingAdvanceError: Binding<Bool> {
        Binding(
            get: { advanceErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    advanceErrorMessage = nil
                }
            }
        )
    }

    private func advanceJob() {
        do {
            try JobRepository(context: modelContext).advance(job)
        } catch {
            advanceErrorMessage = "The job could not move to the next step."
        }
    }

    private func progressColor(for stepState: WorkflowProgressStepState) -> Color {
        stepState == .upcoming ? .secondary.opacity(0.25) : .accentColor
    }
}
