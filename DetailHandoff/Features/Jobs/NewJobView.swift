import SwiftData
import SwiftUI

struct NewJobView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var vehicleLabel = ""
    @State private var customerName = ""
    @State private var plate = ""
    @State private var color = ""
    @State private var serviceName = ""
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle") {
                    TextField("Vehicle", text: $vehicleLabel)
                    TextField("Plate", text: $plate)
                    TextField("Color", text: $color)
                }

                Section("Customer") {
                    TextField("Customer name", text: $customerName)
                }

                Section("Service") {
                    TextField("Service", text: $serviceName)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button("Create job", action: createJob)
                        .frame(maxWidth: .infinity)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New job")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Unable to create job", isPresented: isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unexpected error occurred.")
            }
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func createJob() {
        if let validationError = NewJobValidator.validate(
            vehicleLabel: vehicleLabel,
            serviceName: serviceName
        ) {
            errorMessage = validationError.localizedDescription
            return
        }

        do {
            try JobRepository(context: modelContext).createJob(
                customerName: customerName,
                vehicleLabel: vehicleLabel,
                plate: plate,
                color: color,
                serviceName: serviceName,
                notes: notes
            )
            dismiss()
        } catch {
            errorMessage = "We couldn't save this job. Please try again."
        }
    }
}
