import SwiftUI

/// A temporary read-only handoff destination until the workflow UI is implemented.
struct JobWorkflowView: View {
    let job: JobRecord

    var body: some View {
        List {
            Section("Job") {
                LabeledContent("Vehicle", value: job.vehicleLabel)
                LabeledContent("Service", value: job.serviceName)
                LabeledContent("Status", value: job.status.displayName)
            }
        }
        .navigationTitle(job.vehicleLabel)
    }
}
