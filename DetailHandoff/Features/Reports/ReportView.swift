import SwiftData
import SwiftUI

struct ReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessProfile.createdAt) private var businessProfiles: [BusinessProfile]

    let job: JobRecord

    @State private var history: [ReportVersion] = []
    @State private var presentedPDF: PresentedPDF?
    @State private var shareItem: ReportShareItem?
    @State private var isSealConfirmationPresented = false
    @State private var errorMessage: String?
    @State private var repairDestination: ReportRepairDestination?
    @State private var suggestedRepair: ReportRepairDestination?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing16) {
                reportSummary

                if ReportPresentationPolicy.canPreviewDraft(for: job.status) {
                    reviewActions
                }

                if !history.isEmpty && ReportPresentationPolicy.canOpenStoredVersion(for: job.status) {
                    storedVersions
                }

                if ReportPresentationPolicy.canCreateRevision(for: job.status) {
                    Button(action: createRevision) {
                        Label("Create revision", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("report.createRevision")
                }
            }
            .padding(AppTheme.spacing16)
        }
        .accessibilityIdentifier("report.verticalScroll")
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reloadHistory)
        .onChange(of: job.status) { _, _ in reloadHistory() }
        .sheet(item: $presentedPDF) { item in
            NavigationStack {
                PDFPreview(data: item.data)
                    .navigationTitle(item.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { presentedPDF = nil }
                        }
                    }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .confirmationDialog("Seal report?", isPresented: $isSealConfirmationPresented, titleVisibility: .visible) {
            Button("Seal report") { sealReport() }
                .accessibilityIdentifier("report.confirmSeal")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This creates an immutable PDF. Future changes require a new revision.")
        }
        .alert("Report issue", isPresented: isShowingError) {
            if let suggestedRepair {
                Button(suggestedRepair.buttonTitle) {
                    errorMessage = nil
                    repairDestination = suggestedRepair
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "The report could not be opened.")
        }
        .navigationDestination(item: $repairDestination) { destination in
            switch destination {
            case let .capture(phase):
                CaptureView(job: job, phase: phase)
            case .acknowledgment:
                AcknowledgmentView(job: job)
            }
        }
    }

    private var reportSummary: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(job.status == .archived ? "Archived report" : "Vehicle condition report")
                .font(.title3.weight(.semibold))
            Text(job.vehicleLabel)
            Text(job.status == .archived ? "This record is retained for viewing and sharing." : "Reports stay on this device until you choose to share a sealed version.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .reportCard()
    }

    private var reviewActions: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            Text("Review and seal").font(.headline)
            Text("Preview is marked draft and does not create a report version.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: previewDraft) {
                Label("Preview draft", systemImage: "doc.richtext")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("report.previewDraft")

            Button {
                isSealConfirmationPresented = true
            } label: {
                Label("Seal report", systemImage: "checkmark.seal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("report.seal")

            NavigationLink {
                AcknowledgmentView(job: job)
            } label: {
                Label("Review customer acknowledgment", systemImage: "signature")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("report.acknowledgment")
        }
        .reportCard()
    }

    private var storedVersions: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            Text("Sealed versions").font(.headline)
            if history.isEmpty {
                Text("No readable sealed version is available.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(history.reversed()) { version in
                    versionRow(version)
                }
            }
        }
        .reportCard()
    }

    private func versionRow(_ version: ReportVersion) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text("\(version.reportNumber) · Version \(version.version)")
                .font(.subheadline.weight(.semibold))
            Text("Sealed \(version.sealedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Checksum \(version.sha256)")
                .font(.caption2.monospaced())
                .textSelection(.enabled)
                .accessibilityLabel("Checksum \(version.sha256)")

            HStack {
                Button("Preview") { openStoredVersion(version) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("report.preview.\(version.id.uuidString)")
                Button("Share") { shareStoredVersion(version) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("report.share.\(version.id.uuidString)")
            }
        }
        .padding(.vertical, AppTheme.spacing8)
        .accessibilityIdentifier("report.version.\(version.id.uuidString)")
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                    suggestedRepair = nil
                }
            }
        )
    }

    private var business: BusinessProfile? {
        businessProfiles.first
    }

    private func reloadHistory() {
        do {
            history = try ReportRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot)).versions(for: job)
        } catch {
            history = []
            present(error: error)
        }
    }

    private func previewDraft() {
        guard let business else {
            present(message: "Add business details before preparing a report.")
            return
        }
        do {
            let data = try ReportRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot)).preview(job: job, business: business)
            presentedPDF = PresentedPDF(title: "Draft preview", data: data)
        } catch {
            present(error: error)
        }
    }

    private func sealReport() {
        guard let business else {
            present(message: "Add business details before sealing a report.")
            return
        }
        do {
            _ = try ReportRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot)).seal(job: job, business: business)
            reloadHistory()
        } catch {
            present(error: error)
        }
    }

    private func createRevision() {
        do {
            try ReportRepository(context: modelContext, media: MediaStore(root: MediaStore.defaultRoot)).beginRevision(job: job)
            reloadHistory()
        } catch {
            present(error: error)
        }
    }

    private func openStoredVersion(_ version: ReportVersion) {
        do {
            let asset = try ReportAssetLoader.load(version: version, media: MediaStore(root: MediaStore.defaultRoot))
            presentedPDF = PresentedPDF(title: "\(version.reportNumber) v\(version.version)", data: asset.data)
        } catch {
            present(error: error)
        }
    }

    private func shareStoredVersion(_ version: ReportVersion) {
        do {
            let asset = try ReportAssetLoader.load(version: version, media: MediaStore(root: MediaStore.defaultRoot))
            shareItem = ReportShareItem(url: asset.url)
        } catch {
            present(error: error)
        }
    }

    private func present(error: Error) {
        suggestedRepair = nil
        switch error {
        case let ReportRepositoryError.incompleteCapture(phase):
            suggestedRepair = .capture(phase)
            present(message: "Complete the \(phase == .before ? "Before" : "After") capture before sealing this report.")
        case ReportRepositoryError.missingAcknowledgment, ReportRepositoryError.staleAcknowledgment:
            suggestedRepair = .acknowledgment
            present(message: "Record a current customer acknowledgment before sealing this report.")
        case let error as LocalizedError:
            present(message: error.errorDescription ?? "The report could not be completed.")
        default:
            present(message: "The report could not be completed. \(error.localizedDescription)")
        }
    }

    private func present(message: String) {
        errorMessage = message
    }
}

private struct PresentedPDF: Identifiable {
    let id = UUID()
    let title: String
    let data: Data
}

private struct ReportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private enum ReportRepairDestination: Identifiable, Hashable {
    case capture(CapturePhase)
    case acknowledgment

    var id: String {
        switch self {
        case let .capture(phase): "capture-\(phase.rawValue)"
        case .acknowledgment: "acknowledgment"
        }
    }

    var buttonTitle: String {
        switch self {
        case let .capture(phase): "Open \(phase == .before ? "Before" : "After") capture"
        case .acknowledgment: "Open acknowledgment"
        }
    }
}
