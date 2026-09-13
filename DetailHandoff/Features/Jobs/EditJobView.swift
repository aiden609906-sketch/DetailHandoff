import SwiftData
import SwiftUI

struct EditJobView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let job: JobRecord
    @State private var customerName: String
    @State private var customerPhone: String
    @State private var customerEmail: String
    @State private var vehicleLabel: String
    @State private var plate: String
    @State private var color: String
    @State private var serviceName: String
    @State private var location: String
    @State private var notes: String
    @State private var saveError: String?
    @State private var isSaving = false

    init(job: JobRecord) {
        self.job = job
        _customerName = State(initialValue: job.customerName)
        _customerPhone = State(initialValue: job.customerPhone ?? "")
        _customerEmail = State(initialValue: job.customerEmail ?? "")
        _vehicleLabel = State(initialValue: job.vehicleLabel)
        _plate = State(initialValue: job.plate)
        _color = State(initialValue: job.color)
        _serviceName = State(initialValue: job.serviceName)
        _location = State(initialValue: job.location ?? "")
        _notes = State(initialValue: job.notes)
    }

    var body: some View {
        Form {
            Section("Vehicle") {
                TextField("Vehicle", text: $vehicleLabel)
                TextField("Plate", text: $plate)
                TextField("Color", text: $color)
            }
            Section("Customer") {
                TextField("Customer name", text: $customerName)
                TextField("Phone (optional)", text: $customerPhone).keyboardType(.phonePad)
                TextField("Email (optional)", text: $customerEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
            Section("Service") {
                TextField("Service", text: $serviceName)
                TextField("Service location (optional)", text: $location)
            }
            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
            }
            if isSaving { ProgressView("Saving changes") }
            if let saveError {
                Section {
                    Text(saveError).foregroundStyle(.red)
                    Button("Retry", action: saveNow)
                }
            }
        }
        .navigationTitle("Edit job")
        .onChange(of: customerName) { saveNow() }
        .onChange(of: customerPhone) { saveNow() }
        .onChange(of: customerEmail) { saveNow() }
        .onChange(of: vehicleLabel) { saveNow() }
        .onChange(of: plate) { saveNow() }
        .onChange(of: color) { saveNow() }
        .onChange(of: serviceName) { saveNow() }
        .onChange(of: location) { saveNow() }
        .onChange(of: notes) { saveNow() }
    }

    private func saveNow() {
        isSaving = true
        do {
            try JobRepository(context: modelContext).updateDetails(
                job,
                customerName: customerName,
                customerPhone: customerPhone,
                customerEmail: customerEmail,
                vehicleLabel: vehicleLabel,
                plate: plate,
                color: color,
                serviceName: serviceName,
                location: location,
                notes: notes
            )
            saveError = nil
        } catch {
            saveError = "Changes weren’t saved. Check the required vehicle and service fields, then retry."
        }
        isSaving = false
    }
}
