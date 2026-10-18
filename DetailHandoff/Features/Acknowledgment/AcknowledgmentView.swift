import SwiftData
import SwiftUI

struct AcknowledgmentView: View {
    @Environment(\.modelContext) private var modelContext

    let job: JobRecord
    let stage: AcknowledgmentStage

    init(job: JobRecord, stage: AcknowledgmentStage = .preService) {
        self.job = job
        self.stage = stage
    }

    @State private var document = CaptureDocument.empty
    @State private var customerName = ""
    @State private var strokes: [SignatureStroke] = []
    @State private var unavailableReason = ""
    @State private var isUnavailablePromptPresented = false
    @State private var errorMessage: String?
    @State private var savedRecord: AcknowledgmentRecord?
    @State private var savedRecordIsCurrent = false
    @State private var isReplacingRecord = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing16) {
                Text(stage == .preService ? "Confirm before service" : "Confirm completed service")
                    .font(.title2.weight(.semibold))
                Text(stage == .preService
                     ? "Review the visible starting condition and selected service before recording the customer’s acknowledgment."
                     : "Review the completed service and final vehicle condition before recording the customer’s acknowledgment.")
                    .foregroundStyle(.secondary)

                serviceSummary
                evidence
                findings

                if let savedRecord {
                    savedAcknowledgment(savedRecord)
                }

                if savedRecord == nil || isReplacingRecord {
                    acknowledgmentEditor
                }
            }
            .padding(AppTheme.spacing16)
        }
        .navigationTitle("Acknowledgment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !isReplacingRecord { customerName = job.customerName }
            reloadDocument()
        }
        .alert("Customer unavailable", isPresented: $isUnavailablePromptPresented) {
            TextField("Reason", text: $unavailableReason)
            Button("Record") { recordUnavailable() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A reason is required when the customer cannot sign.")
        }
        .alert("Acknowledgment issue", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "The acknowledgment could not be saved.")
        }
    }

    private func savedAcknowledgment(_ record: AcknowledgmentRecord) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            Text(savedRecordIsCurrent ? "Current acknowledgment" : "The reviewed evidence changed. A new acknowledgment is required.")
                .font(.headline)
                .accessibilityIdentifier("acknowledgment.status")
            Text(record.confirmationText)
            Text(record.customerName.isEmpty ? "Customer name not recorded" : record.customerName)
                .accessibilityIdentifier("acknowledgment.savedName")
            Text("Recorded \(record.recordedAt.formatted(date: .abbreviated, time: .standard))")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("acknowledgment.savedTime")
            if record.method == .signature {
                SignaturePad(strokes: .constant(record.strokes))
                    .disabled(true)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Saved customer signature")
                    .accessibilityIdentifier("acknowledgment.savedSignature")
            } else {
                Text("Customer unavailable").font(.subheadline.weight(.semibold))
                Text(record.unavailableReason)
                    .accessibilityIdentifier("acknowledgment.unavailableReason")
            }
            if isMutable && !isReplacingRecord {
                Button("Replace acknowledgment") {
                    customerName = job.customerName
                    strokes = []
                    unavailableReason = ""
                    isReplacingRecord = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("acknowledgment.replace")
            }
        }
        .reportCard()
    }

    private var acknowledgmentEditor: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            Text(stage.confirmationText)
                .font(.body.weight(.medium))
            TextField("Customer name", text: $customerName)
                .textFieldStyle(.roundedBorder)
            SignaturePad(strokes: $strokes)
            HStack {
                Button("Clear signature", role: .destructive) { strokes = [] }
                    .disabled(strokes.isEmpty || !isMutable)
                Spacer()
                Button("Record signature") { recordSignature() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isMutable)
            }
            Button("Customer unavailable") { isUnavailablePromptPresented = true }
                .buttonStyle(.bordered)
                .disabled(!isMutable)
            if isReplacingRecord {
                Button("Cancel replacement") {
                    isReplacingRecord = false
                    strokes = []
                    unavailableReason = ""
                }
                .accessibilityIdentifier("acknowledgment.cancelReplacement")
            }
        }
        .reportCard()
        .disabled(!isMutable)
    }

    private var serviceSummary: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text("Selected service").font(.headline)
            Text(job.serviceName.isEmpty ? "No service recorded" : job.serviceName)
            LabeledContent("Vehicle", value: job.vehicleLabel)
        }
        .reportCard()
    }

    @ViewBuilder
    private var evidence: some View {
        let phases: [CapturePhase] = stage == .preService ? [.before] : CapturePhase.allCases
        let photos = document.photos.filter { phases.contains($0.phase) }
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(stage == .preService ? "Before photos" : "Before and After photos").font(.headline)
            if photos.isEmpty {
                Text("No reviewed photos are recorded; any skipped views are listed below.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: AppTheme.spacing8) {
                        ForEach(photos) { photo in
                            ThumbnailImage(photo: photo)
                                .frame(width: 128, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
            ForEach(Array(document.skips.filter { phases.contains($0.phase) }.enumerated()), id: \.offset) { _, skip in
                Text("\(skip.phase == .before ? "Before" : "After") · \(slotName(for: skip.slotID)): skipped — \(skip.reason)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .reportCard()
    }

    @ViewBuilder
    private var findings: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text("Visible findings").font(.headline)
            if document.findings.isEmpty {
                Text("No findings recorded.").foregroundStyle(.secondary)
            } else {
                ForEach(document.findings) { finding in
                    Text("\(finding.kind) · \(finding.severity) · \(slotName(for: finding.slotID))")
                    if !finding.notes.isEmpty { Text(finding.notes).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .reportCard()
    }

    private var isMutable: Bool { job.status != .finalized && job.status != .archived }

    private func slotName(for id: String) -> String {
        document.slots.first(where: { $0.id == id })?.name ?? id
    }

    private func reloadDocument() {
        do {
            document = try CaptureRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot)).document(for: job)
            let repository = AcknowledgmentRepository(context: modelContext)
            savedRecord = try repository.record(for: job, stage: stage)
            savedRecordIsCurrent = try repository.isCurrent(job: job, stage: stage)
        } catch {
            errorMessage = "Acknowledgment evidence could not be read. \(error.localizedDescription)"
        }
    }

    private func recordSignature() {
        do {
            try AcknowledgmentRepository(context: modelContext).sign(job: job, stage: stage, name: customerName, strokes: strokes)
            isReplacingRecord = false
            strokes = []
            reloadDocument()
        } catch {
            errorMessage = "The signature could not be recorded. \(error.localizedDescription)"
        }
    }

    private func recordUnavailable() {
        do {
            try AcknowledgmentRepository(context: modelContext).markUnavailable(job: job, stage: stage, reason: unavailableReason)
            isReplacingRecord = false
            unavailableReason = ""
            reloadDocument()
        } catch {
            errorMessage = "The unavailable acknowledgment could not be recorded. \(error.localizedDescription)"
        }
    }
}
