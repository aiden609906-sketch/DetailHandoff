import SwiftData
import SwiftUI

struct JobWorkflowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let job: JobRecord

    @State private var advanceErrorMessage: String?
    @State private var isShowingReport = false
    @State private var workflowContentMetrics = WorkflowScrollContentMetrics()
    @State private var workflowViewportWidth: CGFloat = 0
    @State private var workflowHorizontalOffset: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing24) {
                jobSummary
                workflowProgress
                WorkflowStepContent(status: job.status)

                if job.status == .review {
                    primaryWorkflowAction
                }

                captureDestination

                NavigationLink {
                    PhotoExportView(job: job)
                } label: {
                    WorkflowActionLabel("Export job photos", systemImage: "square.and.arrow.up")
                }

                if job.status != .review {
                    primaryWorkflowAction
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.spacing16)
        }
        .accessibilityIdentifier("workflow.verticalScroll")
        .navigationTitle(job.vehicleLabel)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isShowingReport) {
            ReportView(job: job)
        }
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
            if job.status != .finalized, job.status != .archived {
                NavigationLink {
                    EditJobView(job: job)
                } label: {
                    Label("Edit job details", systemImage: "pencil")
                }
                .padding(.top, AppTheme.spacing8)
            }
        }
        .reportCard()
    }

    private var workflowProgress: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            Text("Workflow progress")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
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
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: WorkflowScrollContentMetricsPreferenceKey.self,
                            value: WorkflowScrollContentMetrics(
                                width: proxy.size.width
                            )
                        )
                    }
                }
                .background {
                    WorkflowScrollOffsetObserver(
                        horizontalOffset: $workflowHorizontalOffset
                    )
                }
            }
            .accessibilityIdentifier("workflow.horizontalScroll")
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: WorkflowScrollViewportWidthPreferenceKey.self,
                        value: proxy.size.width
                    )
                }
            }
            .onPreferenceChange(WorkflowScrollContentMetricsPreferenceKey.self) {
                workflowContentMetrics = $0
            }
            .onPreferenceChange(WorkflowScrollViewportWidthPreferenceKey.self) {
                workflowViewportWidth = $0
            }

            persistentScrollIndicator
        }
    }

    private var persistentScrollIndicator: some View {
        GeometryReader { proxy in
            let viewportWidth = WorkflowProgressLayout.resolvedViewportWidth(
                measuredWidth: workflowViewportWidth,
                trackWidth: proxy.size.width
            )
            let metrics = WorkflowProgressLayout.scrollIndicatorMetrics(
                contentWidth: max(
                    workflowContentMetrics.width,
                    minimumWorkflowContentWidth
                ),
                viewportWidth: viewportWidth,
                contentMinX: -workflowHorizontalOffset,
                trackWidth: proxy.size.width
            )

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(Color.accentColor.opacity(0.75))
                        .frame(width: metrics.thumbWidth)
                        .offset(x: metrics.thumbOffset)
                }
                .opacity(metrics.isScrollable ? 1 : 0)
                .accessibilityHidden(true)

                workflowIndicatorDiagnostic(thumbOffset: metrics.thumbOffset)
            }
        }
        .frame(height: 5)
    }

    @ViewBuilder
    private func workflowIndicatorDiagnostic(thumbOffset: CGFloat) -> some View {
#if DEBUG
        if isUIDiagnosticsEnabled {
            Text("Workflow scroll indicator diagnostic")
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("diagnostic.workflow.scrollIndicator")
                .accessibilityLabel("Workflow scroll indicator diagnostic")
                .accessibilityValue(String(Double(thumbOffset)))
        }
#else
        EmptyView()
#endif
    }

    private var minimumWorkflowContentWidth: CGFloat {
        WorkflowProgressLayout.minimumContentWidth(
            stepCount: JobStatus.allCases.count,
            stepWidth: WorkflowProgressLayout.minimumStepWidth(for: dynamicTypeSize),
            spacing: AppTheme.spacing8
        )
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
                WorkflowActionLabel("Record customer acknowledgment", systemImage: "signature")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("workflow.acknowledgment")
        case .afterCapture:
            captureActions(phase: .after)
        case .awaitingCompletionAcknowledgment:
            VStack(spacing: AppTheme.spacing8) {
                NavigationLink {
                    AcknowledgmentView(job: job, stage: .completion)
                } label: {
                    WorkflowActionLabel("Record completion acknowledgment", systemImage: "signature")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("workflow.completionAcknowledgment")
                photoPairsLink
            }
        case .review:
            VStack(spacing: AppTheme.spacing8) {
                photoPairsLink
                NavigationLink {
                    FindingsView(job: job)
                } label: {
                    WorkflowActionLabel("Inspect findings", systemImage: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("workflow.findings")
                captureCorrection(phase: .before)
                captureCorrection(phase: .after)
            }
        case .finalized, .archived:
            VStack(spacing: AppTheme.spacing8) {
                NavigationLink {
                    ReportView(job: job)
                } label: {
                    WorkflowActionLabel(job.status == .archived ? "View archived report" : "View sealed report", systemImage: "doc.text")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(job.status == .archived ? "workflow.archivedReport" : "workflow.sealedReport")
                photoPairsLink
            }
        default:
            EmptyView()
        }
    }

    private func captureCorrection(phase: CapturePhase) -> some View {
        NavigationLink {
            CaptureView(job: job, phase: phase)
        } label: {
            WorkflowActionLabel("Edit \(phase == .before ? "Before" : "After") photos", systemImage: "camera")
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier(phase == .before ? "workflow.editBeforeCapture" : "workflow.editAfterCapture")
    }

    private func captureActions(phase: CapturePhase) -> some View {
        VStack(spacing: AppTheme.spacing8) {
            NavigationLink {
                CaptureView(job: job, phase: phase)
            } label: {
                WorkflowActionLabel("Open \(phase == .before ? "Before" : "After") capture", systemImage: "camera")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(phase == .before ? "workflow.openBeforeCapture" : "workflow.openAfterCapture")
            NavigationLink {
                FindingsView(job: job)
            } label: {
                WorkflowActionLabel("Record findings", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("workflow.findings")
            photoPairsLink
        }
    }

    private var photoPairsLink: some View {
        NavigationLink {
            PhotoPairView(job: job)
        } label: {
            WorkflowActionLabel("Inspect photo pairs", systemImage: "rectangle.split.2x1")
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("workflow.photoPairs")
    }

    @ViewBuilder
    private var primaryWorkflowAction: some View {
        switch WorkflowPresentationPolicy.primaryAction(for: job.status) {
        case let .advance(nextStatus):
            Button(action: advanceJob) {
                WorkflowActionLabel("Continue to \(nextStatus.displayName)", systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case .reviewAndSealCurrentRevision:
            Button {
                isShowingReport = true
            } label: {
                WorkflowActionLabel("Review and seal current revision", systemImage: "checkmark.seal")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("workflow.report")
        case .none:
            EmptyView()
        }
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
            case .missingCompletionAcknowledgment:
                advanceErrorMessage = "Record the customer's completion acknowledgment before reviewing the report."
            case .staleCompletionAcknowledgment:
                advanceErrorMessage = "The completed-service evidence changed. Review it and record a new completion acknowledgment."
            case .corruptCompletionAcknowledgment:
                advanceErrorMessage = "The saved completion acknowledgment cannot be read. Record it again before continuing."
            case .reportSealRequired:
                advanceErrorMessage = "Generate and seal a report to finalize this job."
            case .immutableJob, .blankVehicle, .blankService:
                advanceErrorMessage = "The job details are invalid or can no longer be changed."
            }
        } catch {
            advanceErrorMessage = "The job could not move to the next step."
        }
    }

    private func progressColor(for stepState: WorkflowProgressStepState) -> Color {
        stepState == .upcoming ? .secondary.opacity(0.25) : .accentColor
    }

#if DEBUG
    private var isUIDiagnosticsEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-diagnostics")
            && ProcessInfo.processInfo.environment["XCUI_TESTING"] == "1"
    }
#endif
}

private struct WorkflowScrollContentMetrics: Equatable {
    var width: CGFloat = 0
}

private struct WorkflowScrollContentMetricsPreferenceKey: PreferenceKey {
    static let defaultValue = WorkflowScrollContentMetrics()

    static func reduce(value: inout WorkflowScrollContentMetrics, nextValue: () -> WorkflowScrollContentMetrics) {
        value = nextValue()
    }
}

private struct WorkflowScrollViewportWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct WorkflowActionLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .labelStyle(WorkflowActionLabelStyle(vertical: dynamicTypeSize.isAccessibilitySize))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }
}

private struct WorkflowActionLabelStyle: LabelStyle {
    let vertical: Bool

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if vertical {
            VStack(spacing: AppTheme.spacing8) {
                configuration.icon
                configuration.title
            }
        } else {
            HStack(spacing: AppTheme.spacing8) {
                configuration.icon
                configuration.title
            }
        }
    }
}
