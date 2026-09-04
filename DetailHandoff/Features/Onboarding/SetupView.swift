import SwiftData
import SwiftUI

struct SetupView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var businessName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var selectedServiceID = BusinessConfiguration.standard.services[0].id
    @State private var selectedTemplateID = BusinessConfiguration.standard.defaultTemplateID
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Business name", text: $businessName)
                        .textContentType(.organizationName)

                    TextField("Phone (optional)", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)

                    TextField("Email (optional)", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                } header: {
                    Text("Business details")
                } footer: {
                    Text("Your records stay on this device.")
                }

                Section("Defaults for your first job") {
                    Picker("Default service", selection: $selectedServiceID) {
                        ForEach(BusinessConfiguration.standard.services) { service in
                            Text(service.name).tag(service.id)
                        }
                    }
                    Picker("Capture template", selection: $selectedTemplateID) {
                        ForEach(BusinessConfiguration.standard.templates) { template in
                            Text(template.name).tag(template.id)
                        }
                    }
                }

                Section("Before you begin") {
                    Text(BusinessProfile().disclaimer)
                    Text("Your reports and photos are stored only on this device. Back up the device regularly; deleting the app or losing the device can permanently lose local records.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Set up your business")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveProfile)
                        .disabled(!canSave)
                }
            }
            .alert("Couldn’t save business details", isPresented: saveErrorIsPresented) {
                Button("OK", role: .cancel) {
                    saveError = nil
                }
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private var canSave: Bool {
        !businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { isPresented in
                if !isPresented {
                    saveError = nil
                }
            }
        )
    }

    private func saveProfile() {
        let trimmedBusinessName = businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBusinessName.isEmpty else { return }

        do {
            var configuration = BusinessConfiguration.standard
            configuration.defaultTemplateID = selectedTemplateID
            configuration = configuration.makingServiceDefault(selectedServiceID)
            _ = try BusinessRepository(context: modelContext).createProfile(
                businessName: trimmedBusinessName,
                phone: phone,
                email: email,
                configuration: configuration
            )
        } catch {
            saveError = error.localizedDescription
        }
    }
}
