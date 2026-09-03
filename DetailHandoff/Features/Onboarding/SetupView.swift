import SwiftData
import SwiftUI

struct SetupView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var businessName = ""
    @State private var phone = ""
    @State private var email = ""
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

        let businessProfile = BusinessProfile(
            businessName: trimmedBusinessName,
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        modelContext.insert(businessProfile)

        do {
            try modelContext.save()
        } catch {
            modelContext.delete(businessProfile)
            saveError = error.localizedDescription
        }
    }
}
