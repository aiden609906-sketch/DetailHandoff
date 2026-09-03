import SwiftUI

struct WorkflowStepContent: View {
    let status: JobStatus

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(status.displayName)
                .font(.headline)

            Text(instruction)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .reportCard()
    }

    private var instruction: String {
        switch status {
        case .draft:
            "Review the vehicle and service details."
        case .beforeCapture:
            "Capture the vehicle before work begins."
        case .awaitingAcknowledgment:
            "Review the visible condition with the customer."
        case .inProgress:
            "The service is underway."
        case .afterCapture:
            "Capture the finished vehicle from the same positions."
        case .review:
            "Check the record before creating the report."
        case .finalized:
            "This report version is sealed."
        case .archived:
            "This job is archived."
        }
    }
}
