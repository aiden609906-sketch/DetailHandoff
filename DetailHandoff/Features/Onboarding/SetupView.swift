import Foundation
import PhotosUI
import SwiftData
import SwiftUI

struct SetupView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var businessName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var services = BusinessConfiguration.standard.services
    @State private var selectedServiceID = BusinessConfiguration.standard.services[0].id
    @State private var selectedTemplateID = BusinessConfiguration.standard.defaultTemplateID
    @State private var selectedLogo: PhotosPickerItem?
    @State private var logoData: Data?
    @State private var isLoadingLogo = false
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

                    PhotosPicker(selection: $selectedLogo, matching: .images) {
                        Label(logoData == nil ? "Add logo (optional)" : "Logo selected", systemImage: "photo")
                    }
                    .accessibilityIdentifier("setup.logoPicker")
                } header: {
                    Text("Business details")
                } footer: {
                    Text("Your records stay on this device.")
                }

                Section("Defaults for your first job") {
                    ForEach(services.indices, id: \.self) { index in
                        TextField("Service", text: $services[index].name)
                            .accessibilityIdentifier("setup.service.\(index)")
                    }
                    Picker("Default service", selection: $selectedServiceID) {
                        ForEach(services) { service in
                            Text(service.name).tag(service.id)
                        }
                    }
                    Picker("Capture template", selection: $selectedTemplateID) {
                        ForEach(BusinessConfiguration.standard.templates) { template in
                            Text(template.name).tag(template.id)
                        }
                    }
                    .accessibilityIdentifier("setup.templatePicker")
                }

                Section("Before you begin") {
                    Text(BusinessProfile().disclaimer)
                    Text("Your reports and photos are stored only on this device. Back up the device regularly; deleting the app or losing the device can permanently lose local records.")
                        .foregroundStyle(.secondary)
                }
                Section("Already have a backup?") {
                    NavigationLink("Restore existing backup") { BackupView(canExport: false) }
                }
            }
            .navigationTitle("Set up your business")
            .task(id: selectedLogo) { await loadLogo() }
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
        !businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !isLoadingLogo &&
            services.contains(where: { $0.id == selectedServiceID }) &&
            services.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
            configuration.services = services
            configuration.defaultTemplateID = selectedTemplateID
            configuration = configuration.makingServiceDefault(selectedServiceID)
            _ = try BusinessRepository(context: modelContext).createProfile(
                businessName: trimmedBusinessName,
                phone: phone,
                email: email,
                configuration: configuration,
                logoData: logoData
            )
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func loadLogo() async {
        guard let selectedLogo else {
            logoData = nil
            return
        }
        isLoadingLogo = true
        defer { isLoadingLogo = false }
        do {
            let bytes = try await selectedLogo.loadTransferable(type: Data.self)
            try Task.checkCancellation()
            guard let bytes else { throw CocoaError(.fileReadCorruptFile) }
            logoData = bytes
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            logoData = nil
            saveError = "The logo couldn’t be loaded. Try a different image."
        }
    }
}
