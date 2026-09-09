import SwiftData
import SwiftUI

struct NewJobView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessProfile.createdAt) private var businessProfiles: [BusinessProfile]

    @State private var vehicleLabel = ""
    @State private var customerName = ""
    @State private var plate = ""
    @State private var color = ""
    @State private var serviceName = ""
    @State private var selectedServiceIDs = Set<UUID>()
    @State private var selectedTemplateID: UUID?
    @State private var customerPhone = ""
    @State private var customerEmail = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle") {
                    TextField("Vehicle", text: $vehicleLabel)
                        .focused($focusedField, equals: .vehicle)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                    TextField("Plate", text: $plate)
                    TextField("Color", text: $color)
                }

                Section("Customer") {
                    TextField("Customer name", text: $customerName)
                    TextField("Phone (optional)", text: $customerPhone)
                        .keyboardType(.phonePad)
                    TextField("Email (optional)", text: $customerEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }

                Section("Service") {
                    ForEach(configuration.services) { service in
                        Toggle(service.name, isOn: Binding(
                            get: { selectedServiceIDs.contains(service.id) },
                            set: { selected in
                                if selected { selectedServiceIDs.insert(service.id) }
                                else { selectedServiceIDs.remove(service.id) }
                            }
                        ))
                    }
                    TextField("Other service (optional)", text: $serviceName)
                    Picker("Capture template", selection: $selectedTemplateID) {
                        ForEach(configuration.templates) { template in
                            Text(template.name).tag(Optional(template.id))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    TextField("Service location (optional)", text: $location)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button("Create job", action: createJob)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("newJob.create")
                }
            }
            .accessibilityIdentifier("newJob.verticalScroll")
            .formStyle(.grouped)
            .navigationTitle("New job")
            .onAppear {
                guard selectedTemplateID == nil else { return }
                selectedTemplateID = configuration.defaultTemplateID
                if let firstService = configuration.services.first {
                    selectedServiceIDs = [firstService.id]
                }
            }
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
        let selectedServices = configuration.services
            .filter { selectedServiceIDs.contains($0.id) }
            .map(\.name)
        let resolvedServiceName = ([selectedServices.joined(separator: ", "), serviceName.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty })
            .joined(separator: ", ")
        if let validationError = NewJobValidator.validate(
            vehicleLabel: vehicleLabel,
            serviceName: resolvedServiceName
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
                serviceName: resolvedServiceName,
                notes: notes,
                customerPhone: customerPhone,
                customerEmail: customerEmail,
                location: location,
                template: configuration.templates.first(where: { $0.id == selectedTemplateID })
            )
            dismiss()
        } catch {
            errorMessage = "We couldn't save this job. Please try again."
        }
    }

    private var configuration: BusinessConfiguration {
        guard let profile = businessProfiles.first else { return .standard }
        return (try? BusinessRepository(context: modelContext).configuration(for: profile)) ?? .standard
    }

    private enum Field: Hashable {
        case vehicle
    }
}
