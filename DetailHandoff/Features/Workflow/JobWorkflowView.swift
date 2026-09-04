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

                captureDestination

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

    @ViewBuilder
    private var captureDestination: some View {
        switch job.status {
        case .beforeCapture:
            captureActions(phase: .before)
        case .awaitingAcknowledgment:
            NavigationLink {
                AcknowledgmentView(job: job)
            } label: {
                Label("Record customer acknowledgment", systemImage: "signature")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        case .afterCapture:
            captureActions(phase: .after)
        case .review, .finalized, .archived:
            VStack(spacing: AppTheme.spacing8) {
                NavigationLink {
                    PhotoPairView(job: job)
                } label: {
                    Label("Inspect photo pairs", systemImage: "rectangle.split.2x1")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                NavigationLink {
                    FindingsView(job: job)
                } label: {
                    Label("Inspect findings", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        default:
            EmptyView()
        }
    }

    private func captureActions(phase: CapturePhase) -> some View {
        VStack(spacing: AppTheme.spacing8) {
            NavigationLink {
                CaptureView(job: job, phase: phase)
            } label: {
                Label("Open \(phase == .before ? "Before" : "After") capture", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            NavigationLink {
                FindingsView(job: job)
            } label: {
                Label("Record findings", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            NavigationLink {
                PhotoPairView(job: job)
            } label: {
                Label("Inspect photo pairs", systemImage: "rectangle.split.2x1")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
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
        } catch let error as JobRepositoryError {
            switch error {
            case .incompleteCapture(let phase, let missingSlots):
                let phaseName = phase == .before ? "Before photos" : "After photos"
                advanceErrorMessage = "Complete \(phaseName) before continuing. Missing: \(missingSlots.map(\.name).joined(separator: ", "))."
            case .corruptCapture(let phase):
                let phaseName = phase == .before ? "before" : "after"
                advanceErrorMessage = "The saved \(phaseName) capture record is invalid. Open capture to review it before continuing."
            case .noNextStatus:
                advanceErrorMessage = "This job has no later workflow step."
            case .missingAcknowledgment:
                advanceErrorMessage = "Record a customer acknowledgment before service begins."
            case .staleAcknowledgment:
                advanceErrorMessage = "Before-service evidence changed. Review it and record a new acknowledgment before continuing."
            case .corruptAcknowledgment:
                advanceErrorMessage = "The saved acknowledgment cannot be read. Record it again before continuing."
            case .reportSealRequired:
                advanceErrorMessage = "Generate and seal a report to finalize this job."
            }
        } catch {
            advanceErrorMessage = "The job could not move to the next step."
        }
    }

    private func progressColor(for stepState: WorkflowProgressStepState) -> Color {
        stepState == .upcoming ? .secondary.opacity(0.25) : .accentColor
    }
}
