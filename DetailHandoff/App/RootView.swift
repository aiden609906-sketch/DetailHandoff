import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var restoredContext: ModelContext?
    @State private var generation = UUID()
    @State private var showingRestoreSuccess = false

    var body: some View {
        RootContentView()
            .modelContext(restoredContext ?? modelContext)
            .id(generation)
            .onReceive(NotificationCenter.default.publisher(for: .evidenceStoreRestored)) { notification in
                guard let container = notification.object as? ModelContainer,
                      container === modelContext.container else { return }
                restoredContext = ModelContext(container)
                generation = UUID()
                showingRestoreSuccess = true
            }
            .alert("Restore complete", isPresented: $showingRestoreSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Jobs and settings were replaced successfully. Your restored records are ready to use.")
            }
    }
}

private struct RootContentView: View {
    @Query(sort: \BusinessProfile.createdAt) private var businessProfiles: [BusinessProfile]

    var body: some View {
        if let businessProfile = businessProfiles.first {
            TabView {
                JobsListView()
                    .tabItem {
                        Label("Jobs", systemImage: "list.bullet")
                    }

                SettingsView(businessProfile: businessProfile)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
        } else {
            SetupView()
        }
    }
}
