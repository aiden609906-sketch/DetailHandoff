import PhotosUI
import SwiftData
import SwiftUI

struct SettingsView: View {
    let businessProfile: BusinessProfile

    var body: some View {
        NavigationStack {
            Form {
                Section("Business") {
                    NavigationLink("Business details and disclaimer") {
                        BusinessDetailsView(profile: businessProfile)
                    }
                    NavigationLink("Services and capture templates") {
                        ServicesAndTemplatesView(profile: businessProfile)
                    }
                }
                Section("Data safety") {
                    NavigationLink("Backup and restore") { BackupView() }
                    NavigationLink("Storage") { StorageView() }
                    NavigationLink("Recently deleted") { RecentlyDeletedView() }
                }
                Section("Privacy") {
                    Text("Records stay on this device.")
                    Text("No account, analytics, or cloud service is used.")
                }
                Section("About") {
                    Text("Detail Handoff")
                    Text("Version 0.1.0")
                }
                Section("Support") {
                    Text("Add a real support contact to your release checklist before distribution.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct BusinessDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    let profile: BusinessProfile
    @State private var name: String
    @State private var phone: String
    @State private var email: String
    @State private var disclaimer: String
    @State private var selectedLogo: PhotosPickerItem?
    @State private var errorMessage: String?

    init(profile: BusinessProfile) {
        self.profile = profile
        _name = State(initialValue: profile.businessName)
        _phone = State(initialValue: profile.phone)
        _email = State(initialValue: profile.email)
        _disclaimer = State(initialValue: profile.disclaimer)
    }

    var body: some View {
        Form {
            Section("Branding") {
                TextField("Business name", text: $name)
                TextField("Phone (optional)", text: $phone).keyboardType(.phonePad)
                TextField("Email (optional)", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                PhotosPicker(selection: $selectedLogo, matching: .images) {
                    Label(profile.logoImagePath == nil ? "Add logo (optional)" : "Replace logo", systemImage: "photo")
                }
            }
            Section("Report disclaimer") {
                TextField("Disclaimer", text: $disclaimer, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .navigationTitle("Business details")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) } }
        .task(id: selectedLogo) { await importLogo() }
        .alert("Couldn’t save business details", isPresented: showingError) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private var showingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func save() {
        do {
            let repository = BusinessRepository(context: modelContext)
            try repository.updateDetails(profile, businessName: name, phone: phone, email: email, disclaimer: disclaimer, configuration: try repository.configuration(for: profile))
        } catch {
            errorMessage = "Changes weren’t saved. Enter a business name and try again."
        }
    }

    private func importLogo() async {
        guard let selectedLogo else { return }
        defer { if self.selectedLogo == selectedLogo { self.selectedLogo = nil } }
        do {
            try await EvidenceImport.loadAndSave(load: { try await selectedLogo.loadTransferable(type: Data.self) }, save: { data in
                try BusinessRepository(context: modelContext).importLogo(data, for: profile)
            })
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = "The logo couldn’t be saved. Try a different image."
        }
    }
}

private struct ServicesAndTemplatesView: View {
    @Environment(\.modelContext) private var modelContext
    let profile: BusinessProfile
    @State private var configuration: BusinessConfiguration
    @State private var errorMessage: String?
    @State private var removalWarning: String?

    init(profile: BusinessProfile) {
        self.profile = profile
        _configuration = State(initialValue: .standard)
    }

    var body: some View {
        Form {
            Section("Saved services") {
                ForEach($configuration.services) { $service in
                    TextField("Service", text: $service.name)
                }
                .onMove { configuration.services.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { configuration.services.remove(atOffsets: $0) }
                Button("Add service") { configuration.services.append(ServiceOption(name: "")) }
            }
            Section("Capture templates") {
                ForEach($configuration.templates) { $template in
                    NavigationLink {
                        CaptureTemplateEditor(template: $template)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(template.name.isEmpty ? "Untitled template" : template.name)
                            Text("\(template.slots.count) capture positions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove { configuration.templates.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { offsets in
                    if offsets.contains(where: { configuration.templates[$0].id == configuration.defaultTemplateID }) {
                        removalWarning = "This is the default capture template. Choose another default before removing it."
                    } else {
                        configuration.templates.remove(atOffsets: offsets)
                    }
                }
                Button("Add template") {
                    configuration.templates.append(CaptureTemplateOption(name: "", slots: CaptureSlot.standard))
                }
                Picker("Default template", selection: $configuration.defaultTemplateID) {
                    ForEach(configuration.templates) { template in
                        Text(template.name.isEmpty ? "Untitled template" : template.name).tag(template.id)
                    }
                }
            }
        }
        .navigationTitle("Services and templates")
        .onAppear {
            configuration = (try? BusinessRepository(context: modelContext).configuration(for: profile)) ?? .standard
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) { EditButton() }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
        }
        .alert("Template in use", isPresented: warningShown) { Button("OK", role: .cancel) {} } message: { Text(removalWarning ?? "") }
        .alert("Couldn’t save templates", isPresented: errorShown) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private var warningShown: Binding<Bool> {
        Binding(get: { removalWarning != nil }, set: { if !$0 { removalWarning = nil } })
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func save() {
        do {
            try BusinessRepository(context: modelContext).updateDetails(profile, businessName: profile.businessName, phone: profile.phone, email: profile.email, disclaimer: profile.disclaimer, configuration: configuration)
        } catch {
            errorMessage = "Each service and template needs a name, and every template needs capture positions."
        }
    }
}

private struct CaptureTemplateEditor: View {
    @Binding var template: CaptureTemplateOption

    var body: some View {
        List {
            Section("Template") {
                TextField("Template name", text: $template.name)
            }
            Section("Capture positions") {
                ForEach($template.slots) { $slot in
                    VStack(alignment: .leading) {
                        TextField("Position name", text: $slot.name)
                        TextField("Stable position ID", text: $slot.id)
                            .font(.caption)
                            .textInputAutocapitalization(.never)
                        Toggle("Required", isOn: $slot.isRequired)
                    }
                }
                .onMove { template.slots.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { template.slots.remove(atOffsets: $0) }
                Button("Add capture position") {
                    template.slots.append(CaptureSlot(id: UUID().uuidString.lowercased(), name: "", isRequired: true))
                }
            }
        }
        .navigationTitle("Capture template")
        .toolbar { ToolbarItem(placement: .primaryAction) { EditButton() } }
    }
}
