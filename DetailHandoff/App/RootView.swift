import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var restoredContext: ModelContext?
    @State private var generation = UUID()
    @State private var showingRestoreSuccess = false
    @State private var retentionError: String?

    var body: some View {
        RootContentView()
            .modelContext(restoredContext ?? modelContext)
            .id(generation)
            .task { purgeExpiredJobs() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { purgeExpiredJobs() }
            }
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
            .alert("Storage cleanup needs attention", isPresented: Binding(get: { retentionError != nil }, set: { if !$0 { retentionError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(retentionError ?? "")
            }
    }

    private func purgeExpiredJobs() {
        do {
            try TrashService(context: restoredContext ?? modelContext, media: MediaStore(root: MediaStore.defaultRoot)).purgeExpired()
        } catch { retentionError = error.localizedDescription }
    }
}

private struct RootContentView: View {
    @Query(sort: \BusinessProfile.createdAt) private var businessProfiles: [BusinessProfile]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            .accessibilityIdentifier("ui.dynamicType.\(dynamicTypeIdentifier)")
        } else {
            SetupView()
        }
    }

    private var dynamicTypeIdentifier: String {
        switch dynamicTypeSize {
        case .xSmall: "xSmall"
        case .small: "small"
        case .medium: "medium"
        case .large: "large"
        case .xLarge: "xLarge"
        case .xxLarge: "xxLarge"
        case .xxxLarge: "xxxLarge"
        case .accessibility1: "accessibility1"
        case .accessibility2: "accessibility2"
        case .accessibility3: "accessibility3"
        case .accessibility4: "accessibility4"
        case .accessibility5: "accessibility5"
        @unknown default: "unknown"
        }
    }
}
