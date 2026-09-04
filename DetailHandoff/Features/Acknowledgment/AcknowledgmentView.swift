import SwiftData
import SwiftUI

struct AcknowledgmentView: View {
    @Environment(\.modelContext) private var modelContext

    let job: JobRecord

    @State private var document = CaptureDocument.empty
    @State private var customerName = ""
    @State private var strokes: [SignatureStroke] = []
    @State private var unavailableReason = ""
    @State private var isUnavailablePromptPresented = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing16) {
                Text("Confirm before service")
                    .font(.title2.weight(.semibold))
                Text("Review the visible starting condition and selected service before recording the customer’s acknowledgment.")
                    .foregroundStyle(.secondary)

                serviceSummary
                beforeEvidence
                findings

                VStack(alignment: .leading, spacing: AppTheme.spacing12) {
                    Text(AcknowledgmentRecord.confirmationText)
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
                }
                .reportCard()

                Button("Customer unavailable") {
                    isUnavailablePromptPresented = true
                }
                .buttonStyle(.bordered)
                .disabled(!isMutable)
            }
            .padding(AppTheme.spacing16)
        }
        .navigationTitle("Acknowledgment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            customerName = job.customerName
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

    private var serviceSummary: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text("Selected service").font(.headline)
            Text(job.serviceName.isEmpty ? "No service recorded" : job.serviceName)
            LabeledContent("Vehicle", value: job.vehicleLabel)
        }
        .reportCard()
    }

    @ViewBuilder
    private var beforeEvidence: some View {
        let photos = document.photos.filter { $0.phase == .before }
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text("Before photos").font(.headline)
            if photos.isEmpty {
                Text("No Before photos are recorded; any skipped views are listed below.")
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
            ForEach(document.skips.filter { $0.phase == .before }, id: \.slotID) { skip in
                Text("\(slotName(for: skip.slotID)): skipped — \(skip.reason)")
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
        } catch {
            errorMessage = "Capture records could not be read. \(error.localizedDescription)"
        }
    }

    private func recordSignature() {
        do {
            try AcknowledgmentRepository(context: modelContext).sign(job: job, name: customerName, strokes: strokes)
        } catch {
            errorMessage = "The signature could not be recorded. \(error.localizedDescription)"
        }
    }

    private func recordUnavailable() {
        do {
            try AcknowledgmentRepository(context: modelContext).markUnavailable(job: job, reason: unavailableReason)
            unavailableReason = ""
        } catch {
            errorMessage = "The unavailable acknowledgment could not be recorded. \(error.localizedDescription)"
        }
    }
}
